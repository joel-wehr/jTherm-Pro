// Agent code
const TWILIO_ACCOUNT_SID = ""
const TWILIO_AUTH_TOKEN = ""
const TWILIO_FROM_NUMBER = "" // your phone no goes here
const TWILIO_TO_NUMBER = "" // destination phone no

http.onrequest(function(request, response) { 
  try {
    local data = http.jsondecode(request.body);
    // make sure we got all the values we're expecting
    if ("trigger1min" in data) {
      server.log(data.trigger1min);
      device.send("Trigger1Min", data);
      response.send(200, "OK");
    } 
    else if ("trigger1max" in data) {
        server.log(data.trigger1max);
        device.send("Trigger1Max", data);
        response.send(200, "OK");        
    }
    else if ("trigger2min" in data) {
        server.log(data.trigger2min);
        device.send("Trigger2Min", data);
        response.send(200, "OK");
    }
    else if ("trigger2max" in data) {
        server.log(data.trigger2max);
        device.send("Trigger2Max", data);
        response.send(200, "OK");
    }
   else {
        response.send(500, "Missing Data in Body");
   }     
  }
  catch (ex) {
    response.send(500, "Internal Server Error: " + ex);
  }
});
function send_sms(number, message) {
    local twilio_url = format("https://api.twilio.com/2010-04-01/Accounts/%s/SMS/Messages.json", TWILIO_ACCOUNT_SID);
    local auth = "Basic " + http.base64encode(TWILIO_ACCOUNT_SID+":"+TWILIO_AUTH_TOKEN);
    local body = http.urlencode({From=TWILIO_FROM_NUMBER, To=number, Body=message});
    local req = http.post(twilio_url, {Authorization=auth}, body);
    local res = req.sendsync();
    if(res.statuscode != 201) {
        server.log("error sending message: "+res.body);
    }
}

device.on("Probe1", function(v) {
    send_sms(TWILIO_TO_NUMBER, "Probe 1: " + v);
});
device.on("Probe2", function(v) {
    send_sms(TWILIO_TO_NUMBER, "Probe 2: " + v);
});
