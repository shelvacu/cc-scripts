import * as MessagePack from "@msgpack/msgpack";
import Cookies from "js-cookie";
import { setConstantValue } from "typescript";
export type SqlValue =
  {ty: "bool", val: boolean}|
  {ty: "char"|"int"|"smallint"|"tinyint"|"oid"|"bigint"|"real"|"double"|"int4", val: number}|
  {ty: "text", val: string}|
  {ty: "bytea", val: number[]}|
  {ty: "json"|"jsonb", val: any}|
  {ty: "null", val: null};

let msgs = new Map<number, [(rows:SqlValue[][])=>void,(err:string)=>void]>(); // msgid => [successCallback, failCallback]
let prepareds = new Map<number, [(rows:number)=>void,(err:string)=>void]>(); // msgid => [successCallback, failCallback]
let notifyListeners = new Map<string, (data: {process_id: number, channel: string, payload: string} )=>void>(); // channel => callback
let msgid = 0;
//let socket = new WebSocket("ws://10.244.65.57:7648/");
const loc = window.location;
let new_uri;
if (loc.protocol === "https:") {
    new_uri = "wss:";
} else {
    new_uri = "ws:";
}
new_uri += "//" + loc.host;
new_uri += loc.pathname + "/ws";

let socket = new WebSocket(Cookies.get("ws-override") || new_uri);
//@ts-ignore
window.theSocket = socket;
//@ts-ignore
window.mp = MessagePack;  
//@ts-ignore
window.Cookies = Cookies;
let openPromise:Promise<WebSocket> = new Promise(function(success, fail) {
  let onOpen = function() {
    console.log("Websocket open!");
    success(socket);
  }
  socket.onopen = onOpen;
  if (socket.readyState === WebSocket.OPEN) {
    onOpen();
  }
});

type Pg2WsMessage =
  {ty: "results", msgid: number, rows: SqlValue[][]}|
  {ty: "prepared", msgid: number, id: number}|
  {ty: "notification", channel: string, payload: string, process_id: number}|
  {ty: "error", msgid: number|null, msg: string}
;

socket.onmessage = function(msgEv) {
  //window.debugData = msgEv.data;
  let res = new Response(msgEv.data);
  res.arrayBuffer().then(data => {
    let parsed = MessagePack.decode(data) as any as Pg2WsMessage;
    if (parsed.ty === "results") {
      let msgCallbacks;
      if((msgCallbacks = msgs.get(parsed.msgid))){
        let cb = msgCallbacks[0];
        let rows = (parsed.rows.map((row) => row.map((sval) => sval.ty == "null" ? {ty: "null", val: null} as SqlValue : sval)));
        cb(rows);
      }
      msgs.delete(parsed.msgid)
    } else if (parsed.ty === "prepared") {
      let msgCallbacks
      (msgCallbacks = prepareds.get(parsed.msgid)) && msgCallbacks[0](parsed.id);
      prepareds.delete(parsed.msgid)
    } else if (parsed.ty === "notification") {
      (notifyListeners.get(parsed.channel) || (function(){}))(parsed)
    } else if (parsed.ty === "error") {
      if (parsed.msgid) {
        let c;
        if ((c = msgs.get(parsed.msgid))) {
          c[1](parsed.msg);
          msgs.delete(parsed.msgid);
        }
        let d;
        if ((d = prepareds.get(parsed.msgid))) {
          d[1](parsed.msg);
          prepareds.delete(parsed.msgid);
        }
      } else {
        for (const v of msgs.values()) {
          v[1](parsed.msg)
        }
        socket.close();
      }
    } else {
      console.log(`ERR: unrecognized message type`, parsed);
      socket.close();
    }
  });
}

export function sqlQuery(str:string, params:SqlValue[]):Promise<SqlValue[][]> {
  if(!params) {
    params = [];
  }
  console.log(str, params);
  let myMsgid = (msgid += 1);
  let data = MessagePack.encode({ty: "query",  statement: str, params: params, msgid: myMsgid});
  return openPromise.then(ws => ws.send(data))
    .then(_ => new Promise((success, fail) => msgs.set(myMsgid, [success, fail])));
}
