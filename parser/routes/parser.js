const express = require('express');
const router = express.Router();;
const nodemailer = require('nodemailer');

router.post('/send-mail', (req, res) => {
    const smtpTransport = nodemailer.createTransport({
        host: '',
        port: 25,
        secure: false,
        auth: {
            user: '',
            pass: ''
        },
        tls: {
            // do not fail on invalid certs
            rejectUnauthorized: false
        }
    });

    const mailOptions = {
        from: req.body.sender,
        to: req.body.recipients,
        subject: req.body.subject,
        attachments: req.body.attachments,
        text: req.body.text
    };

    // verify connection configuration
    smtpTransport.verify(function (error, success) {
        if (error) {
            console.log(error);
            res.status(200).json({
                message: 'Failed'
            });
        } else {
            console.log('Server is ready to take our messages');

            smtpTransport.sendMail(mailOptions, function (error, info) {
                if (error) {
                    console.log(error);
                    res.status(200).json({
                        error: 'email sending failed'
                    });
                    console.log('email sending failed');
                } else {
                    console.log('email sending Success');
                    res.status(200).json({
                        message: 'Success'
                    });
                }
            });
        }
    });

});

module.exports = router;
