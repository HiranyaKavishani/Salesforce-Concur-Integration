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

import ballerina/http;
import ballerina/log;
import ballerina/io;
import ballerina/config;
import ballerina/mime;

endpoint http:Listener listener {
    port: config:getAsInt("BALLERINA_PORT", default = BALLERINA_PORT_DEFAULT)
};

@http:ServiceConfig {
    basePath: "/"
}
service<http:Service> startTimerTask bind listener {
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/start"
    }
    startTask(endpoint caller, http:Request req) {
        http:Response res = new;

        scheduleAppointment(config:getAsString("SF_PROCESS_CRON", default = SF_PROCESS_CRON_DEFAULT));

        json message = { "message": "service started" };
        res.setJsonPayload(message);
        log:printInfo("service started");

        caller->respond(res) but {
            error e => log:printError("Error sending response", err = e)

        };
    }

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/stop"
    }
    stopTask(endpoint caller, http:Request req) {
        http:Response res = new;

        cancelAppointment();
        json message = { "message": "service stopped" };
        res.setJsonPayload(message);
        log:printInfo("service stopped");

        caller->respond(res) but {
            error e => log:printError("Error sending response", err = e)

        };
    }

}
