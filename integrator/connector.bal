import ballerina/file;
import ballerina/http;
import ballerina/internal;
import ballerina/io;
import ballerina/log;
import ballerina/time;


string parentlistId = config:getAsString("LINKED_LIST_ID");

endpoint http:Client httpConcurAuthEndpoint {
    url: config:getAsString("ACCESS_TOKEN_URL")
};


function getAccessTokenAndRefreshToken() returns @untainted (string,string)|error {

    http:Request tokenRequest;
    string accessToken;
    string refreshToken;

    string clientId = config:getAsString("CLIENT_ID");
    string clientSecret = config:getAsString("CLIENT_SECRET");
    string password = config:getAsString("PASSWORD");
    string username = config:getAsString("USERNAME");
    string grantType = config:getAsString("ACCESS_TOCKEN_GRANT_TYPE");

    tokenRequest.setTextPayload("client_id=" + clientId + "&client_secret=" + clientSecret + "&grant_type=" + grantType
            + "&username=" + username + "&password=" + password, contentType = mime:APPLICATION_FORM_URLENCODED);

    var tokenresponse = httpConcurAuthEndpoint->post("", tokenRequest);
    match tokenresponse {
        http:Response resp => {
            var msg = resp.getJsonPayload();
            match msg {
                json jsonPayload => {
                    match getAccessToken(jsonPayload) {
                        string token => {
                            accessToken = token;
                        }
                        error err => {
                            log:printError(err.message,err = err);
                        }
                        () => {
                        }
                    }

                    match getRefreshToken(jsonPayload) {
                        string token => {
                            refreshToken = refreshToken;
                        }
                        error err => {
                            log:printError(err.message,err = err);
                        }
                        () => {
                        }
                    }
                    return (accessToken,refreshToken);
                }
                error tokenResponseErr => {
                    log:printError(tokenResponseErr.message, err = tokenResponseErr);
                    return tokenResponseErr;
                }

            }
        }
        error err => {
            log:printError(err.message, err = err);
            return err;
        }
    }
}

function getAccessToken(json response) returns string|error? {
    match  <string>response.access_token {
        string stringToken => {
            return stringToken;
        }
        error matchAccessToken => {
            log:printError(matchAccessToken.message, err = matchAccessToken);
        }
    }
    return;
}

function getRefreshToken(json response) returns string|error? {
    match  <string>response.refresh_token {
        string stringToken => {
            return stringToken;
        }
        error getRefreshTokenErr => {
            log:printError(getRefreshTokenErr.message, err = getRefreshTokenErr);
        }
    }
    return;
}

function sanitizeitems(string name, string parentId, string level01, string level02, string level03)
             returns @untainted xml {

    string listId = parentlistId;
    xml payload = xml `<ListItem xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="
    http://www.w3.org/2001/XMLSchema-instance">
                <ListID>{{listId}}</ListID>
                <Name>{{name}}</Name>
                <ParentID xsi:nil="true">{{parentId}}</ParentID>
                <Level1Code>{{level01}}</Level1Code>
                <Level2Code xsi:nil="true">{{level02}}</Level2Code>
                <Level3Code xsi:nil="true">{{level03}}</Level3Code>
                </ListItem>`;

    return payload;
}

function getConcurEndPoint(string newAccessToken,string refreshToken) returns http:Client {

    endpoint http:Client concurDataUploadEndpoint {
        url: config:getAsString("API_CALL_URL"),
        keepAlive: "NEVER",
        // Add this to create new connection with concur in every record creation, since concur doesn't support for keepAlive conncection until upload all items
        auth: {
            scheme: http:OAUTH2,
            accessToken: newAccessToken,
            clientId: config:getAsString("CLIENT_ID"),
            clientSecret: config:getAsString("CLIENT_SECRET"),
            refreshToken: refreshToken,
            refreshUrl: config:getAsString("REFRESH_URL"),
            username: config:getAsString("USERNAME"),
            password: config:getAsString("PASSWORD")
        }
    };
    //log:printInfo(config:getAsString("CLIENT_ID"));
    return concurDataUploadEndpoint;
}

function uploadDataToConcur(ConcurItem[] datalist, string newAccessToken,string refreshToken) returns error? {

    endpoint http:Client concurDataUploadEndpoint = getConcurEndPoint(newAccessToken,refreshToken);

    http:Request request;
    xml requestPayload;
    AggregateObject dataRecord;

    AccessCredentials tokens;
    tokens.refreshToken = refreshToken;
    tokens.accessToken = newAccessToken;

    time:Time time = time:currentTime();
    int year; int month;int day;
    (year, month, day) = time.getDate();
    string currentDate = year + "_" + month + "_" + day;
    string saveContentPath = config:getAsString("SAVE_CONTENT_PATH") + currentDate + "_ItemStatus.txt";

    foreach data in datalist {
        dataRecord.data = data;
        requestPayload = sanitizeitems(data.name, "", data.name, "", "");
        request.setContentType(mime:APPLICATION_XML);
        request.setPayload(requestPayload);

        var level01Response = concurDataUploadEndpoint->post("", request);
        match level01Response {
            http:Response resp => {
                match levelOneXmlResponseHandler(resp, dataRecord, tokens){
                    () => {
                    }
                    error xmlHandlingErr => {
                        log:printError(xmlHandlingErr.message, err = xmlHandlingErr);
                    }
                }
            }
            error levelTwoResponseErr => {
                log:printError(levelTwoResponseErr.message, err = levelTwoResponseErr);
                dataRecord.otherErrors[lengthof dataRecord.otherErrors] = levelTwoResponseErr.message;
                return levelTwoResponseErr;
            }
        }
    }


    io:println(lengthof dataRecord.itemUploadedContents);
    io:ByteChannel byteChannel = io:openFile(saveContentPath, io:APPEND);

    if (lengthof dataRecord.itemUploadedContents > 0){
        dataRecord.itemUploadedContents[0] = "ITEMS WHICH ARE SUCCESSFULLY UPLOADED TO THE CONCUR:\n\n"
            + dataRecord.itemUploadedContents[0];
        writeContentInfile(dataRecord.itemUploadedContents,byteChannel,saveContentPath);
    }
    if (lengthof dataRecord.itemUploadedErrors > 0){
        dataRecord.itemUploadedErrors[0] = "\n\n\nITEMS WHICH ARE FAIL TO UPLOAD TO THE CONCUR:\n\n"
            + dataRecord.itemUploadedErrors[0];
        writeContentInfile(dataRecord.itemUploadedErrors,byteChannel,saveContentPath);
    }

    closeByteChannel(byteChannel);

    json emailAttachment = {
        filename: currentDate + "_ItemStatus",
        path: saveContentPath
    };

    if (lengthof datalist > 0) {
        match sendEmail(emailAttachment,"") {
            () => {
                log:printInfo("Email sent successfully");
            }
            error e => {
                log:printError(e.message, err = e);
            }

        }
    }

    internal:Path text = new(saveContentPath);

    match text.delete() {
        () => {
            log:printInfo("Internal Status File is deleted Successfully");
        }
        error e => {
            log:printError(e.message);
        }
    }
    return ();
}


function levelOneXmlResponseHandler(http:Response resp, AggregateObject dataRecord, AccessCredentials tokens)
             returns error? {

    dataRecord.data.suffixList = "PR,PO," + dataRecord.data.suffixList;
    string[] suffixList = dataRecord.data.suffixList.split(",");

    match resp.getXmlPayload() {
        xml payloadLevelOne => {
            string levelOneListId = "";

            if (resp.statusCode == http:OK_200){
                dataRecord.itemUploadedContents[lengthof dataRecord.itemUploadedContents] =
                    formSuccessMessage ("Level 01",dataRecord.data.name,"","");

                log:printInfo("project Item : " + dataRecord.data.name + "is already uploaded");
                xml levelOneId = payloadLevelOne.selectDescendants(RESPONSE_ID);
                levelOneListId = levelOneId.getTextValue();
            } else {
                string errMsg = payloadLevelOne.selectDescendants(RESPONSE_MESSAGE).getTextValue();
                dataRecord.itemUploadedErrors[lengthof dataRecord.itemUploadedErrors] =
                    formErrorMessage ("Level 01",dataRecord.data.name,"","",errMsg);

                log:printInfo("level 01: '" + dataRecord.data.name + "' is failed to upload.\nErrorMessage:" + errMsg);
            }

            foreach suffix in suffixList {
                match uploadAllProjectCodes(suffix,levelOneListId,dataRecord,tokens){
                    () => {
                        log:printInfo("");
                    }
                    error err => {
                        return err;
                    }
                }
            }
        }
        error levelOneXmlhandlingErr => {
            log:printError(levelOneXmlhandlingErr.message, err = levelOneXmlhandlingErr);
            dataRecord.otherErrors[lengthof dataRecord.otherErrors] = levelOneXmlhandlingErr.message;
            return levelOneXmlhandlingErr;
        }
    }
    return();
}

function uploadAllProjectCodes(string suffix,string levelOnelistId,AggregateObject dataRecord,AccessCredentials tokens)
             returns error? {

    endpoint http:Client concurDataUploadEndpoint = getConcurEndPoint(tokens.accessToken,tokens.refreshToken);
    string projectCode = dataRecord.data.engagementCode + "-" + suffix;
    http:Request request;

    xml requestPayloadLevelTwo = sanitizeitems( projectCode, levelOnelistId, dataRecord.data.name, projectCode, "");
    request.setContentType(mime:APPLICATION_XML);
    request.setPayload(requestPayloadLevelTwo);

    var levelTwoResponse = concurDataUploadEndpoint->post("", request);
    match levelTwoResponse {
        http:Response levelTworesp => {
        match levelTwoXmlResponseHandler(levelTworesp, projectCode, dataRecord, tokens){
            () => {
            }
            error levelTwoXmlhandlingErr => {
                log:printError(levelTwoXmlhandlingErr.message, err = levelTwoXmlhandlingErr);
                return levelTwoXmlhandlingErr;
            }
         }
        }
        error levelTwoResponseErr => {
            log:printError(levelTwoResponseErr.message, err = levelTwoResponseErr);
            dataRecord.itemUploadedErrors[lengthof dataRecord.itemUploadedErrors] = levelTwoResponseErr.message;
            return levelTwoResponseErr;
        }
    }
    return ();
}

function levelTwoXmlResponseHandler(http:Response levelTwoResp,string projectCode,AggregateObject dataRecord,
                                    AccessCredentials tokens) returns error? {

    endpoint http:Client concurDataUploadEndpoint = getConcurEndPoint(tokens.accessToken, tokens.refreshToken);
    match levelTwoResp.getXmlPayload() {
        xml payloadLevelTwo => {
            xml levelTwoId;
            string levelTwolistId = "";
            if (levelTwoResp.statusCode == http:OK_200) {
                dataRecord.itemUploadedContents[lengthof dataRecord.itemUploadedContents] =
                    formSuccessMessage ("Level 02",dataRecord.data.name,projectCode,"");

                log:printInfo("project Item : " + dataRecord.data.name + "/" + projectCode + "is already uploaded");
                levelTwoId = payloadLevelTwo.selectDescendants(RESPONSE_ID);
                levelTwolistId = levelTwoId.getTextValue();
            } else {
                string errMsg = payloadLevelTwo.selectDescendants(RESPONSE_MESSAGE).getTextValue();
                dataRecord.itemUploadedErrors[lengthof dataRecord.itemUploadedErrors] =
                    formErrorMessage ("Level 02",dataRecord.data.name,projectCode,"",errMsg);
                //log:printInfo("level 02: '" + dataRecord.data.name + " |" + projectCode + "' is failed to upload.\nErrorMessage:" + errMsg);
            }

            xml requestPayloadLevel03 = sanitizeitems(dataRecord.data.pod, levelTwolistId, dataRecord.data.name, projectCode,
                dataRecord.data.pod);

            http:Request request;
            request.setContentType(mime:APPLICATION_XML);
            request.setPayload(requestPayloadLevel03);
            var levelThreeResponse = concurDataUploadEndpoint ->post("", request);
            match levelThreeResponse {
                http:Response levelThreeResp => {
                    match levelThreeXmlResponseHandler(levelThreeResp,projectCode,dataRecord,tokens){
                        () => {
                        }
                        error levelThreeXmlhandlingErr => {
                            log:printError(levelThreeXmlhandlingErr.message, err = levelThreeXmlhandlingErr);
                            return levelThreeXmlhandlingErr;
                        }
                    }
                }
                error levelThreeResponseErr => {
                    log:printError(levelThreeResponseErr.message, err = levelThreeResponseErr);
                    dataRecord.itemUploadedErrors[lengthof dataRecord.itemUploadedErrors] = levelThreeResponseErr.message;
                    return levelThreeResponseErr;
                }
            }
        }
        error levelTwoXmlhandlingErr => {
            log:printError(levelTwoXmlhandlingErr.message, err = levelTwoXmlhandlingErr);
            dataRecord.itemUploadedErrors[lengthof dataRecord.itemUploadedErrors] = levelTwoXmlhandlingErr.message;
            return levelTwoXmlhandlingErr;
        }
    }
    return ();
}


function levelThreeXmlResponseHandler(http:Response levelThreeResp,string projectCode,AggregateObject dataRecord,
                                      AccessCredentials tokens) returns error? {

    match levelThreeResp.getXmlPayload() {
        xml xmlPayloadlevelThree => {
            string levelTreelistId = "";
            if (levelThreeResp.statusCode == http:OK_200){
                dataRecord.itemUploadedContents[lengthof dataRecord.itemUploadedContents] =
                    formSuccessMessage ("Level 03",dataRecord.data.name,projectCode,dataRecord.data.pod);

                //log:printInfo("project Item : " + dataRecord.data.name + "/" + projectCode + "/" + dataRecord.data.pod + "is already uploaded");
                xml levelTreeId = xmlPayloadlevelThree.selectDescendants(RESPONSE_ID);
                levelTreelistId = levelTreeId.getTextValue();
            } else {
                string errMsg = xmlPayloadlevelThree.selectDescendants(RESPONSE_MESSAGE).getTextValue();
                dataRecord.itemUploadedErrors[lengthof dataRecord.itemUploadedErrors] =
                    formErrorMessage ("Level 03",dataRecord.data.name,projectCode,dataRecord.data.pod,errMsg);
                //log:printInfo ("level 03: '" + dataRecord.data.name + " |" + projectCode + " |" + dataRecord.data.pod + "' is failed to upload.\nErrorMessage:" + errMsg);
            }
        }
        error levelThreeXmlErr => {
            //log:printInfo("project Item :" + dataRecord.data.name + "/" + projectCode + "/" + dataRecord.data.pod + "is didn't uploaded");
            dataRecord.otherErrors[lengthof dataRecord.otherErrors] = levelThreeXmlErr.message;
            return levelThreeXmlErr;
        }
    }

    return ();
}

function formSuccessMessage(string level,string name,string projectCode,string podName) returns string{
    string message =    level + " :" + name + " |" + projectCode + " |" + podName + "' is suceesfully uploaded";
    return message;
}

function formErrorMessage(string level,string name,string projectCode,string podName,string errorMessage) returns string{
    string message =  level +" :" + name + " |" + projectCode + " |" + podName + "' is failed to upload.\nErrorMessage:"
        + errorMessage;
    return message;
}

function writeContent(byte[] content, string path, io:ByteChannel byteChannel) returns error? {

    var writeResult = byteChannel.write(content, 0);
    match writeResult {
        int noOfBytes => {
            return ();
        }
        error err => {
            return err;
        }
    }
}

function writeContentInfile(string[] arrayOfContent,io:ByteChannel byteChannel,string saveContentPath) {

    foreach content in arrayOfContent {
        content = content + "\n";
        byte[] byteContent = content.toByteArray("UTF-8");

        var results = writeContent(byteContent,saveContentPath,byteChannel);
        match results {
            error e => {
                log:printError(e.message);
            }
            () => {
            }
        }
    }
}

function closeByteChannel(io:ByteChannel byteChannel) {
    match byteChannel.close() {
        error channelCloseError => {
            log:printError("Error occured while closing the channel: ",
                err = channelCloseError);
        }
        () => io:println("Byte channel closed successfully.");
    }
}

