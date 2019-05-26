# sf-concur-integration
This is a sample code of salesforce-concur integration which is developed using ballerina.

In here nodemailer has been used for email notification. But it is also possible to use ballerina package for the email notification.
Documentation: https://central.ballerina.io/wso2/gmail 

Steps to start the service

1. Add mysql driver to bre/lib directory inside ballerina installation location.
Installation location depends on with the OS and for the more information refer: 
https://ballerina.io/learn/getting-started/
2. To start parser, locate the parser folder and enter npm install and npm start
3. To start ballerina integration service, execute -> ballerina run integrator 
4. To start the cron scheduler service,execute -> curl --request POST http://localhost:3001/start
