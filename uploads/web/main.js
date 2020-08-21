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

// setTimeout(function(){
//   alert("readystate is " + socket.readyState);
// }, 2000);

// aq: Aqua Affinity
// ba: Bane of Arthropods
// bp: Blast Protection
// cb: Curse of Binding
// cv: Curse of Vanishing
// ds: Depth Strider
// ef: Efficiency
// ff: Feather Falling
// fa: Fire Aspect
// fp: Fire Protection
// fl: Flame
// fw: Frost Walker
// in: Infinity
// kb: Knockback
// lo: Looting
// ls: Luck of the Sea
// lu: Lure
// me: Mending
// ms: Multishot -- 1.14 enchantment
// pi: Piercing -- 1.14
// po: Power
// pp: Projectile Protection
// pr: Protection
// pu: Punch
// qc: Quick Charge -- 1.14
// re: Respiration
// sh: Sharpness
// st: Silk Touch
// sm: Smite
// ss: Soul Speed -- 1.16
// sw: Sweeping Edge
// th: Thorns
// ub: Unbreaking


const enchantmentData = [
  ["aq", "enchantment.waterWorker", "Aqua Affinity"],
  ["ba", "enchantment.damage.arthropods", "Bane of arthropods"],
  ["bp", "enchantment.protect.explosion", "Blast Protection"],
  ["cb", "enchantment.binding_curse", "Curse of Binding"],
  ["cv", "enchantment.vanishing_curse", "Curse of Vanishing"],
  ["ds", "enchantment.waterWalker", "Depth Strider"],
  ["ef", "enchantment.digging", "Efficiency"],
  ["ff", "enchantment.protect.fall", "Feather Falling"],
  ["fa", "enchantment.fire", "Fire Aspect"],
  ["fp", "enchantment.protect.fire", "Fire Protection"],
  ["fl", "enchantment.arrowFire", "Flame"],
  ["fo", "enchantment.lootBonusDigger", "Fortune"],
  ["fw", "enchantment.frostWalker", "Frost Walker"],
  ["in", "enchantment.arrowInfinite", "Infinity"],
  ["kb", "enchantment.knockback", "Knockback"],
  ["lo", "enchantment.lootBonus", "Looting"],
  ["ls", "enchantment.lootBonusFishing", "Luck of the Sea"],
  ["lu", "enchantment.fishingSpeed", "Lure"],
  ["me", "enchantment.mending", "Mending"],
  ["po", "enchantment.arrowDamage", "Power"],
  ["pp", "enchantment.protect.projectile", "Projectile Protection"],
  ["pr", "enchantment.protect.all", "Protection"],
  ["pu", "enchantment.arrowKnockback", "Punch"],
  ["re", "enchantment.oxygen", "Respiration"],
  ["sh", "enchantment.damage.all", "Sharpness"],
  ["st", "enchantment.untouching", "Silk Touch"],
  ["sm", "enchantment.damage.undead", "Smite"],
  ["sw", "enchantment.sweeping", "Sweeping Edge"],
  ["th", "enchantment.thorns", "Thorns"],
  ["ub", "enchantment.durability", "Unbreaking"]
];

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

function searchSql(query, page) {
  let where_clause = "";
  let sql_params = [];
  let param_idx = 0;
  if(query && query != ""){
    let full = query;
    let [q, ...rest] = full.split(/\s*--?\s*/)
    for (let param of rest.flatMap(s => s.split(/\s+/))){
      let match;
      let row;
      if (match = /^d(\d+)$/i.exec(param)) {
        where_clause += `and item.damage = $${param_idx += 1} `;
        sql_params.push({ty: "int4", val: parseInt(match[1])});
      }else if ((match = /^([a-z][a-z])(\d?)$/.exec(param)) && (row = enchantmentData.find(r => r[0] == match[1]))) {
        let search_json = {name: row[1]};
        if (match[2] != "") {
          search_json.level = parseInt(match[2]);
        }
        where_clause += `and item.fullMeta->'enchantments' @> $${param_idx += 1} `;
        sql_params.push({ty: "jsonb", val: [search_json]});
      }else{
        //ignore
      }
    }   
    q = q.replace(/^mc:/,"minecraft:")
    q = q.replace(/^cc:/,"computercraft:")
    q = q.replace(/\\/g,"\\\\")
    q = q.replace(/%/g,"\\%")
    q = q.replace(/_/g,"\\_")
    if(q != "") {
      where_clause += `and (item.name ilike $${param_idx += 1} or item.fullMeta->>'displayName' ilike $${param_idx += 1}) `;
      sql_params.push({ty: "text", val: q + "%"});
      sql_params.push({ty: "text", val: "%" + q + "%"});
    }
  }
  let sql = "select item.id, item.fullMeta, item.damage, count.count from item, (select item_id, sum(count) as count from stack group by item_id) count where count.item_id = item.id " + where_clause + "order by id limit 100 offset " + 100*(page-1)

  console.log(sql, sql_params);
  return sqlQuery(sql, sql_params).then(res => $.map(res, row => ({id: row[0].val, displayName: row[1].val.displayName, fullMeta: row[1].val, damage: row[2].val, count: row[3].val})));
}

function itemImg(name, damage) {
  let row;
  if (row=blockdata.overrides.find(r => r[0] == name)) {
    return "bigs/" + row[damage + 1];
  }else if (row=blockdata.items.find(r => r[2] == name)) {
    return "smalls/item_" + ((-row[0][0])/16 - row[0][1]) + ".png";
  }else if (row=blockdata.blocks.find(r => r[2] == name)) {
    return "bigs/" + row[0];
  }else{
    return "question.png"
  }
}

function formatCount(count, stackSize, removeCount) {
  let stacks = Math.floor(count/stackSize);
  let singles = count % stackSize;
  if (stacks == 0 || stackSize == 1) {
    return ""+(removeCount ? "" : count);
  }else{
    return `${removeCount ? "" : count} = ${stacks}s ${singles}`;
  }
}

let selected = new Set();

let itemElementCache = new Map();

function formatItem(item) {
  let stackSize = item.fullMeta.maxCount;
  if(itemElementCache.has(item.id)){
    let {res, qtyInput, haveQty, qtySelector, removeButton} = itemElementCache.get(item.id);
    let max = Math.min(item.count, 54*stackSize);
    qtyInput.value = 1;
    qtyInput.max = max;
    haveQty.textContent = "Have: " + formatCount(item.count, stackSize);
    qtySelector.style.display = "none";
    removeButton.style.display = "none";
    res.addEventListener('click', function(){
      document.getElementById("selections").appendChild(res);
      if(item.count > 1) qtySelector.style.display = "";
      removeButton.style.display = "";
      selected.add(item.id);
    }, {once: true});
    return res;
  }

  //console.log(item);
  //let imgSrc = "items/" + item.fullMeta.name.replace("minecraft:","") + ".png"
  let imgSrc = itemImg(item.fullMeta.name, item.damage);
  //let res = $(`<div class="flex-row iteminfo" id="item-${item.id}">`);
  let res = document.createElement("div");
  res.classList.add("flex-row","iteminfo");
  res.id = `item-${item.id}`;
  //let img = $('<img class="item-img">').attr("src", imgSrc);
  let img = document.createElement("img");
  img.classList.add("item-img");
  img.src = imgSrc;
  //img.appendTo(res);
  res.appendChild(img);
  //let infoBox = $('<div class="flex-col" style="flex-grow: 1">');
  let infoBox = document.createElement("div");
  infoBox.classList.add("flex-col");
  infoBox.style = "flex-grow: 1";
  //infoBox.appendTo(res);
  res.appendChild(infoBox);
  //let topInfo = $('<span>');
  let topInfo = document.createElement("span");
  //topInfo.appendTo(infoBox);
  infoBox.appendChild(topInfo);
  //$('<b>').text(item.fullMeta.displayName).appendTo(topInfo);
  let boldName = document.createElement("b");
  boldName.textContent = item.fullMeta.displayName;
  topInfo.appendChild(boldName);
  //let qtySelector = $('<span>').hide();
  let qtySelector = document.createElement("span");
  qtySelector.style.display = "none";
  //qtySelector.appendTo(topInfo);
  topInfo.appendChild(qtySelector);
  let max = Math.min(item.count, 27*stackSize);
  //let qtyInput = $(`<input type="number" value="1" style="width:5em" min="1" max="${max}">`);
  let qtyInput = document.createElement("input");
  qtyInput.type = "number";
  qtyInput.value = 1;
  qtyInput.style.width = "5em";
  qtyInput.min = 1;
  qtyInput.max = max;
  //qtyInput.appendTo(qtySelector);
  qtySelector.appendChild(qtyInput);
  //let qtyEq = $('<span>');
  let qtyEq = document.createElement("span");
  //qtyEq.appendTo(qtySelector);
  qtySelector.appendChild(qtyEq);
  function mkButton(text) { let btn = document.createElement("button"); btn.type = "button"; btn.textContent = text; qtySelector.appendChild(btn); return btn; }
  //let qtyMulStack = $('<button type="button">xS</button>');
  //qtyMulStack.appendTo(qtySelector);
  //let qtyAddStack = $('<button type="button">+S</button>');
  //qtyAddStack.appendTo(qtySelector);
  //let qtyDelStack = $('<button type="button">-S</button>');
  //qtyDelStack.appendTo(qtySelector);
  let qtyMulStack = mkButton("xS");
  let qtyAddStack = mkButton("+S");
  let qtyDelStack = mkButton("-S");
  function updateEq() {
    //qtyEq.text(formatCount(parseInt(qtyInput.val()), stackSize, true));
    qtyEq.textContent = formatCount(parseInt(qtyInput.value), stackSize, true);
  }
  //qtyInput.on('change', updateEq);
  //qtyInput.on('input', updateEq);
  qtyInput.addEventListener('change', updateEq);
  qtyInput.addEventListener('input' , updateEq);
  function changeQty(fn) {
    let oldVal = parseInt(qtyInput.value);
    let newVal = fn(oldVal);
    newVal = Math.min(max, newVal);
    newVal = Math.max(0, newVal);
    //qtyInput.val(newVal);
    qtyInput.value = newVal;
    updateEq();
  }
  //qtyMulStack.on('click', function(){ changeQty(n => n*stackSize) });
  //qtyAddStack.on('click', function(){ changeQty(n => n+stackSize) });
  //qtyDelStack.on('click', function(){ changeQty(n => n-stackSize) });
  qtyMulStack.addEventListener('click', function(){ changeQty(n => n*stackSize) });
  qtyAddStack.addEventListener('click', function(){ changeQty(n => n+stackSize) });
  qtyDelStack.addEventListener('click', function(){ changeQty(n => n-stackSize) });
  if (stackSize == 1) {
    //qtyMulStack.hide();
    //qtyAddStack.hide();
    //qtyDelStack.hide();
    qtyMulStack.style.display = "none";
    qtyAddStack.style.display = "none";
    qtyDelStack.style.display = "none";
  }
  //let removeButton = $('<button type="button">X</button>');
  let removeButton = document.createElement("button");
  removeButton.type = "button";
  removeButton.textContent = "X";
  //removeButton.appendTo(topInfo);
  topInfo.appendChild(removeButton);
  //removeButton.hide();
  removeButton.style.display = "none";
  //removeButton.on('click', function(){ selected.delete(item.id); res.remove(); search($("#search").val()) });
  removeButton.addEventListener("click", function(){ selected.delete(item.id); res.parentElement.removeChild(res); search(document.getElementById("search").value); });
  //$('<div>').text("Have: " + formatCount(item.count, stackSize)).appendTo(infoBox);
  let haveQty = document.createElement("div");
  haveQty.textContent = "Have: " + formatCount(item.count, stackSize);
  infoBox.appendChild(haveQty);
  let descriptionText = item.fullMeta.name;
  if (item.fullMeta.maxDamage > 0) {
    descriptionText += " — D" + item.damage;
  }
  //let extendedDesc = $('<span>');
  let extendedDesc = document.createElement("span");
  if (item.fullMeta.enchantments) {
    extendedDesc.textContent = " — ";
    for(let ench of item.fullMeta.enchantments) {
      let enchData = enchantmentData.find(data => data[1] == ench.name);
      let shortcode;
      if (!enchData) {
        console.log(ench);
        shortcode = "??";
      } else {
        shortcode = enchData[0];
      }
      //descriptionText += shortcode + ench.level + " ";
      //$('<abbr>').attr("title", ench.fullName).text(shortcode + ench.level).appendTo(extendedDesc);
      let enchEl = document.createElement("abbr");
      enchEl.title = ench.fullName;
      enchEl.textContent = shortcode + ench.level;
      extendedDesc.appendChild(enchEl);
      //$(new Text(" ")).appendTo(extendedDesc);
      extendedDesc.appendChild(new Text(" "));
    }
  }
  //$('<div>').text(descriptionText).append(extendedDesc).appendTo(infoBox);
  let thing = document.createElement("div");
  thing.textContent = descriptionText;
  thing.appendChild(extendedDesc);
  infoBox.appendChild(thing);
  // res.on('click', function(){
  //   res.appendTo($("#selections"));
  //   if(item.count > 1) qtySelector.show();
  //   removeButton.show();
  //   selected.add(item.id);
  //   res.off('click');
  // });
  res.addEventListener('click', function(){
    document.getElementById("selections").appendChild(res);
    if(item.count > 1) qtySelector.style.display = "";
    removeButton.style.display = "";
    selected.add(item.id);
  }, {once: true});
  itemElementCache.set(item.id, {res, qtyInput, haveQty, qtySelector, removeButton});
  return res;
}

function search(query) {
  let results = searchSql(query, 1);
  let resultsEl = /*$("#results")*/ document.getElementById("results");
  results.then(results => {
    //resultsEl.empty();
    resultsEl.innerHTML = "";
    for(let r of results) {
      if(!selected.has(r.id)) { 
        //formatItem(r).appendTo(resultsEl);
        let el = formatItem(r);
        resultsEl.appendChild(el);
      }
    }
  });
}

$(document).ready(function() {
  /*$("#bla").select2({
    ajax: {
      transport: selectTransport
    },
    multiple: true,
    closeOnSelect: false,
    scrollAfterSelect: false,
    templateResult: formatItem
  });*/
  //sqlQuery("select * from computer;", []).then(res => document.getElementById("res").innerText = JSON.stringify(res));
  let searchEl = document.getElementById("search");
  searchEl.addEventListener("input", function(ev) {
    search(ev.target.value);
    console.log(ev);
  });

  search(searchEl.value);
  let goButton = document.getElementById("go");
  goButton.addEventListener("click", function(){
    let promises = [];
    for(let [id,_] of selected.entries()){
      let count = parseInt($("#item-"+id+" input").val());
      promises.push(sqlQuery(
        "insert into withdrawal (item_id, computer, output_chest, count) values ($1, $2, $3, $4);",
        [
          {ty: "int4", val: id},
          {ty: "int4", val: 55},
          {ty: "text", val: "minecraft:chest_47"},
          {ty: "int2", val: count}
        ]
      ));//.then(function(){console.log(id); $("#item-"+id).remove();});
    }
    Promise.all(promises).then(_ => {
      sqlQuery("notify withdrawal_rescan");
      for(let [id,_] of selected.entries()){
        $("#item-"+id).remove();
      }
      selected = new Set();
    });

  });
  //query("se
});
