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

type ConcurItem record{
    string name;
    string engagementCode;
    string pod;
    string suffixList;
    string[] surfixes = [];
};

type SFOppoLineItem record{
    string OpportunityId;
    string EngagementCode;
    string SuffixList;
};

type SFOpportunity record{
    string AccountId;
};

type SFAccount record{
    string Name;
    string Global_POD__c;
};

type AggregateObject record{
    ConcurItem data;
    string[] itemUploadedContents;
    string[] itemUploadedErrors;
    string[] otherErrors;
};

type AccessCredentials record{
    string refreshToken;
    string accessToken;
};
