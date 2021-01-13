import * as blockdata from "./blockdata.js";

let msgs = new Map(); // msgid => [successCallback, failCallback]
let notifyListeners = new Map(); // channel => callback
let msgid = 0;
let socket = new WebSocket("ws://10.244.65.57:7648/");
window.theSocket = socket;
//socket.onopen = function(){alert("old onopen called");}
let openPromise = new Promise(function(success, fail) {
  let onOpen = function() {
    console.log("Websocket open!");
    success(socket);
  }
  socket.onopen = onOpen;
  if (socket.readyState == WebSocket.OPEN) {
    onOpen();
  }
});

socket.onmessage = function(msgEv) {
  //window.debugData = msgEv.data;
  let res = new Response(msgEv.data);
  res.arrayBuffer().then(data => {
    let parsed = MessagePack.decode(data);
    if (parsed.ty == "results") {
      msgs.get(parsed.msgid)[0](parsed.rows);
      msgs.delete(parsed.msgid)
    } else if (parsed.ty == "prepared") {
      msgs.get(parsed.msgid)[0](parsed.id);
      msgs.delete(parsed.msgid)
    } else if (parsed.ty == "notification") {
      (notifyListeners.get(parsed.channel) || (function(){}))(parsed)
    } else if (parsed.ty == "error") {
      if (parsed.msgid) {
        msgs.get(parsed.msgid)[1](parsed.msg)
      } else {
        for (const [k,v] of msgs.entries()) {
          v[1](parsed.msg)
        }
      }
    } else {
      console.log(`ERR: unrecognized message type ${parsed.ty}`);
      socket.close()
    }
  });
}

function sqlQuery(str, params) {
  if(!params) {
    params = [];
  }
  console.log(str, params);
  let myMsgid = (msgid += 1);
  return openPromise.then(ws => ws.send(MessagePack.encode({ty: "query",  statement: str, params: params, msgid: myMsgid})))
    .then(_ => new Promise((success, fail) => msgs.set(myMsgid, [success, fail])));
}

let focusdiv = document.getElementById("focusdiv");
let statusdeets = document.getElementById("statusdeets");
let log = document.getElementById("log");
let channelEl = document.getElementById("channel");

notifyListeners.set("turtle_rc_feedback", function(parsed) {
    let payload = JSON.parse(parsed.payload);
    if(payload.channel != channelEl.value) return;
    let facingName = ["north", "east", "south", "west"][payload.position.facing];
    statusdeets.innerText = `fuel:${payload.fuel} x${payload.position.x} y${payload.position.y} z${payload.position.z} ${facingName}`;
    let logLine = `${payload.channel}: ${payload.cmd}: ${JSON.stringify(payload.res)}`;
    let logLineEl = document.createElement("pre");
    logLineEl.innerText = logLine;
    log.prepend(logLineEl);
});

sqlQuery("listen turtle_rc_feedback");
openPromise.then(function(socket) {
    let logLine = 'Socket open';
    let logLineEl = document.createElement("pre");
    logLineEl.innerText = logLine;
    log.prepend(logLineEl);
});

const keyCmd = {
    w: "forward",
    s: "back",
    a: "left",
    d: "right",
    q: "up",
    e: "down",
    r: "dig_up",
    f: "dig_fwd",
    v: "dig_down",
    t: "place_up",
    g: "place_fwd",
    b: "place_down"
};

focusdiv.addEventListener("keydown", function(ev) {
    if(ev.ctrlKey) return true;
    let cmd = keyCmd[ev.key];
    if(cmd == null) return true;
    ev.preventDefault();
    sqlQuery(
        "select pg_notify('turtle_rc_control', $1)::text",
        [{ty: "text", val: JSON.stringify({channel: channelEl.value, cmd: cmd})}]
    );
    return false;
});