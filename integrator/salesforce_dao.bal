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

import ballerina/config;
import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/mysql;
import ballerina/sql;

endpoint mysql:Client salesforceDb {
    host: config:getAsString("DATABASE_HOST"),
    port: config:getAsInt("DATABASE_PORT"),
    name: config:getAsString("DATABASE_NAME"),
    username: config:getAsString("DATABASE_USERNAME"),
    password: config:getAsString("DATABASE_PASSWORD"),
    dbOptions: { useSSL: false }
};


public function getEngagementCodesAndOpportunityIds(string date) returns json {
    json result;
    string sqlString =
    "SELECT DISTINCT OpportunityId, CreatedDate,
		SUBSTRING_INDEX(Engagement_Code_Auto__c, '-', 1) as EngagementCode,
        GROUP_CONCAT(DISTINCT SUBSTRING_INDEX(Engagement_Code_Auto__c, '-', -1) )as SuffixList
        FROM SF_OPPOLINEITEM GROUP BY OpportunityId, SUBSTRING_INDEX(Engagement_Code_Auto__c, '-', 1), CreatedDate HAVING CreatedDate >=?"
    ;

    match callToDatabase(sqlString,date){
        json data => {
            result = data;
        }
    }
    return result;
}

public function getAccountIdFromOpportunityId(string opportunityId) returns json {
    json result = null;
    string sqlString = "SELECT DISTINCT AccountId FROM SF_OPPORTUNITY WHERE Id = ?";

    match callToDatabase(sqlString,opportunityId){
        json data => {
            result = data;
        }
    }
    return result;
}

public function getNamePodFromAccountId(string accountId) returns json {
    json result;
    string sqlString = "SELECT DISTINCT Name,Global_POD__c FROM SF_ACCOUNT WHERE Id = ?";

    match callToDatabase(sqlString,accountId){
        json data => {
            result = data;
        }
    }
    return result;
}

public function callToDatabase(string sqlString,string data) returns json {

    json result;
    var ret = salesforceDb->select(sqlString, (), data);
    match ret {
        table dataTable => {
            result = check <json>dataTable;
        }
        error err => {
            string message = "Failed to upload items.\nDB Error :\n" + err.message;
            match sendEmail(null,untaint message) {
                () => {
                    log:printInfo("Error is notifed successfully");
                }
                error e => {
                    log:printError(e.message);
                }
            }
            done;
        }
    }
    return result;
}
