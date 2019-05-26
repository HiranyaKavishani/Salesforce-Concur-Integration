import ballerina/http;
import ballerina/io;
import ballerina/log;

endpoint http:Client clientEndpoint {
    url: config:getAsString("MAIL_PARSER_HOST", default = PARSER_HOST_DEFAULT)
};

function sendEmail(json attachment,string text) returns error? {
    http:Request request;
    request.setContentType(mime:APPLICATION_JSON);
    json payload = {
        attachments: attachment,
        recipients:config:getAsString("RECIPIENTS_EMAIL", default = RECIPIENTS_EMAIL_DEFAULT),
        sender: config:getAsString("SENDER_EMAIL", default = SENDER_EMAIL_DEFAULT),
        subject: config:getAsString("EMAIL_SUBJECT", default = EMAIL_SUBJECT_DEFAULT),
        text : text
    };

    request.setPayload(payload);
    var response = clientEndpoint->post("/parser/send-mail", request);
    match response {
        http:Response resp => {
            log:printInfo("POST request:");
            var msg = resp.getJsonPayload();
            io:println(msg);
            match msg {
                json jsonPayload => {
                    io:println(jsonPayload);
                    return ();
                }
                error err => {
                    log:printError(err.message, err = err);
                    return err;
                }
            }
        }
        error err => {
            log:printError(err.message, err = err);
            return err;
        }
    }

}
