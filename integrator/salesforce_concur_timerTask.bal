//
// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerina/log;
import ballerina/task;
import ballerina/runtime;
import ballerina/time;
import ballerina/config;

task:Appointment? app;


function main(string... args) {
}
function limitWordCharacterCount(string word) returns string {
    int characterLmit = config:getAsInt("ACCOUNT_NAME_CHARACTER_LIMIT", default = ACCOUNT_NAME_CHARACTER_LIMIT_DEFAULT);
    if (word.length() > characterLmit){
        return word.substring(0, characterLmit);
    } else {
        return word;
    }
}


function processSalesforceData() returns error? {
    time:Time time = time:currentTime();
    xml requestPayload;
    string jsonSaveFile = config:getAsString("JSON_SAVE_FILE", default = JSON_SAVE_FILE_DEFAULT);

    map concurItemMap;
    ConcurItem[] concurItemArray = [];

    match <SFOppoLineItem[]>getEngagementCodesAndOpportunityIds(calculateDateToStart(jsonSaveFile)){
        SFOppoLineItem[] idList => {
            SFOppoLineItem[] list = idList;
            foreach item in idList {
                ConcurItem concurItem;
                concurItem.engagementCode = item.EngagementCode;
                concurItem.suffixList = item.SuffixList;
                log:printInfo(item.OpportunityId);

                match <SFOpportunity>getAccountIdFromOpportunityId(item.OpportunityId)[0]{
                    SFOpportunity accountId => {
                        log:printInfo(accountId.AccountId);
                        match <SFAccount>getNamePodFromAccountId(accountId.AccountId)[0]{
                            SFAccount accountDetails => {
                                concurItem.name = limitWordCharacterCount(accountDetails.Name);
                                concurItem.pod = accountDetails.Global_POD__c;
                            }
                            error err =>{
                                log:printInfo(err.message);
                            }
                        }
                    }
                    error err =>{
                        log:printInfo(err.message);
                    }
                }
                concurItemArray[lengthof concurItemArray] = concurItem;
            }
        }
        error e => {
            log:printInfo(e.message);
        }
    }
        
        // The exmple of concurItemArray which contains the data extracted from salesforce sync
        //ConcurItem[] concurItemArray = [{ name : "A1111", engagementCode : "GXT",pod :"US-EAST", suffixList : "DS,LS" },
        //                   { name : "A0000", engagementCode : "LMN",pod :"US-EAST", suffixList : "QA" },
        //                    { name : "A1111", engagementCode : "GXT",pod :"US-EAST", suffixList : "AS" },
        //                    { name : "A0000", engagementCode : "XXX",pod :"US", suffixList : "AA" }];

        //foreach item in concurItemArray {
        //   item.name = limitWordCharacterCount(item.name);
        //}

        string accessToken;
        string refreshToken;
        json lastRunDate = { "lastRunDate": time.format("yyyy-MM-dd'T'HH:mm:ss.SSSZ") };

        match getAccessTokenAndRefreshToken(){
            (string,string) tokens => {
                (accessToken,refreshToken) = tokens;
                match uploadDataToConcur(concurItemArray,accessToken,refreshToken) {
                    error e => {
                        log:printError(e.message);
                    }
                    ()=> {
                        log:printInfo("Uploaded all records");
                        writeJsonChannel(lastRunDate, jsonSaveFile);
                    }
                }
            }
            error err => {
                log:printError(err.message, err = err);
            }
        }

    return ();
}

function calculateDateToStart(string lastRunDateSavePath) returns string {
    string dateString = check <string>readJsonChannel(lastRunDateSavePath).lastRunDate;
    if (dateString == ""){
        return "";
    } else {
        time:Time parsedDate = time:parse(dateString, "yyyy-MM-dd'T'HH:mm:ss.SSSZ");

        time:Time newTime = parsedDate.addDuration(0, 0, -1 * config:getAsInt("NUMBER_OF_PASSED_DAYS_CHECKED", default =
                    NUMBER_OF_PASSED_DAYS_CHECKED_DEFAULT), 0, 0, 0, 0);

        log:printInfo(newTime.format("yyyy-MM-dd"));
        return newTime.format("yyyy-MM-dd");
    }
}

public function scheduleAppointment(string cronExpression) {
    // Define on trigger function
    (function() returns error?) onTriggerFunction = processSalesforceData;
    // Define on error function
    (function (error)) onErrorFunction = onError;
    // Schedule appointment.
    app = new task:Appointment(onTriggerFunction, onErrorFunction, cronExpression);
    app.schedule();
}

function onError(error e) {
    io:print("[ERROR] failed to execute timed task");
    io:println(e);
}

// Define the function to stop the task.
function cancelAppointment() {
    app.cancel();
}

function writeJsonChannel(json content, string path) {

    io:ByteChannel byteChannel = io:openFile(path, io:WRITE);

    io:CharacterChannel ch = new io:CharacterChannel(byteChannel, "UTF8");

    match ch.writeJson(content) {
        () => {
            closeJsonChannel(ch);
            io:println("Content written successfully");
        }
        error err => {
            closeJsonChannel(ch);
            io:println("Content read error");
        }

    }
}

function readJsonChannel(string path) returns json {
    io:ByteChannel byteChannel = io:openFile(path, io:READ);

    io:CharacterChannel ch = new io:CharacterChannel(byteChannel, "UTF8");

    match ch.readJson() {
        json result => {
            closeJsonChannel(ch);
            return result;
        }
        error err => {
            closeJsonChannel(ch);
            io:println("Content read error");
            throw err;
        }
    }
}

function closeJsonChannel(io:CharacterChannel characterChannel) {
    characterChannel.close() but {
        error e =>
        log:printError("Error occurred while closing character stream",
            err = e)
    };
}