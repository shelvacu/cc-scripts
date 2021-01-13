import React, { isValidElement } from 'react';
import { OrderedMap, List, Set } from 'immutable';
import * as blockdata from './blockdata';
import enchantmentData from './enchantmentData';
import * as db from './database';
import cloneDeep from 'lodash/cloneDeep';
import { fsync } from 'fs';

type HasInvQty = {invQty: number};

const ItemsCache = new Map<number,Item&HasInvQty>();

function preloadItemsCache(ids: number[]):Promise<void> {
  console.log(ids);
  return db.sqlQuery("select i.fullMeta, i.damage, i.id, c.count from item i, lateral (select sum(count) as count from stack where item_id = i.id) c where i.id in (" + ids.join(",") + ");",[]).then((rows) => {
    for(let row of rows) {
      let item = {
        damage: row[1].val as number,
        id: row[2].val as number,
        invQty: row[3].val as number,
        ...(row[0].val as ItemMeta)
      };
      ItemsCache.set(item.id, item);
    }
    return;
  });
}

function getItem(id:number):Promise<Item&HasInvQty> {
  return new Promise(function(suc, fail) {
    if (ItemsCache.has(id)) {
      let res = ItemsCache.get(id);
      if(res == null) throw "wtf";
      suc(res);
    } else {
      preloadItemsCache([id]).then(() => {
        let res = ItemsCache.get(id);
        if(res == null) throw "wtf";
        suc(res);
      });
    }
  });
}

function getCount(id:number):Promise<number> {
  return db.sqlQuery("select sum(count) from stack where item_id = $1",[{ty: "int4", val: id}]).then((rows) => {
    return rows[0][0].val as number;
  });
}

function itemImg(name:string, damage:number):string {
  let row;
  if ((row=blockdata.overrides.find(r => r[0] === name))) {
    return "bigs/" + row[damage + 1];
  }else if ((row=blockdata.items.find(r => r[2] === name))) {
    return "smalls/item_" + ((-row[0][0])/16 - row[0][1]) + ".png";
  }else if ((row=blockdata.blocks.find(r => r[2] === name))) {
    return "bigs/" + row[0];
  }else{
    return "question.png"
  }
}

function StackCount(props:{
  hideCount: boolean,
  count: number,
  stackSize: number
}) {
  let stackCountStr = `= ${Math.floor(props.count / props.stackSize)}s ${props.count % props.stackSize}`;
  return (
    <span className="count">
      {props.hideCount || <span style={{minWidth:"calc(6ch + 3px)", display: "inline-block", textAlign: "right"}}>{props.count}</span>}
      <span style={{minWidth:"11ch", display: "inline-block"}}>&nbsp;
        {props.stackSize > 1 && stackCountStr}
      </span>
    </span>
  );
}

class ScrollableNumberInput extends React.Component<{
  value: number,
  onChange: (newValue: number) => any,
  disabled?: boolean,
  passThru?: object
}, {}> {
  numValue() {
    if (this.props.value) {
      return this.props.value;
    } else {return 0};
  }
  scroll = (ev: {detail: number}) => {
    let newValue;
    if (ev.detail > 0){
      newValue = this.numValue() + 1;
    }else if(ev.detail < 0){
      newValue = this.numValue() - 1;
    }else{
      return;
    }
    this.props.onChange(newValue);
  }
  onChange = (ev: {target: {value: string}}) => {
    let val = ev.target.value;
    this.props.onChange( val === "" ? 0 : parseInt(val) );
  }
  render() {
    return <input 
      type="number"
      value={this.props.value}
      onScroll={this.scroll}
      onChange={this.onChange}
      disabled={this.props.disabled}
      {...(this.props.passThru || {})}
      />
  }
}

type ItemMeta = {
  name: string,
  maxCount: number,
  maxDamage: number,
  enchantments?: {
    name: string,
    fullName: string,
    level: number
  }[],
  displayName: string
};

type Item = {
  damage: number,
  id: number
} & ItemMeta;

type ItemWithCount = {count: number} & Item;

type RecipeProps = {
  ty: "crafting",
  children: {qty: number, job: JobNodeProps&{topLevel: false}}[],
  key: number,
  result_count: number
};

type JobPath = List<number|[number, number]>;

type JobNodeFuncsLoaded = (
  {
    loading: false,
    onSelectedRecipeChange: (path: JobPath, newRecipe: number|null) => any,
    onFromInvQtyChange: (path: JobPath, newQty: number) => any
  }&(
    {topLevel: false}|{
      topLevel: true,
      onRemove: (path: JobPath) => any,
      onQtyChange: (path: JobPath, newQty: number) => any
    }
  )
);

type JobNodeFuncs =
  {
    onSelectedRecipeChange?: (path: JobPath, newRecipe: number|null) => any,
    onFromInvQtyChange?: (path: JobPath, newQty: number) => any,
    onRemove?: (path: JobPath) => any,
    onQtyChange?: (path: JobPath, newQty: number) => any
  }&(
  {loading: true}|{loading: "deferred"}|JobNodeFuncsLoaded);

type JobNodeProps =
  {itemProps: ItemWithCount&HasInvQty, errors:string[]} & (
    {topLevel: boolean}
  ) & ({
    loading: false,
    invAvailQty: number, //not directly editable by user, total quantity minus any quantity used above

    // One of these is editable, the other is calculated from it. Which is which depends on qtyPinMode
    invKeepQty: number,
    invUseQty: number,
    qtyPinMode: "keep"|"use",
  
    recipes: RecipeProps[],
    selectedRecipe: number|null
    //children: [number, JobNodeProps][]
  }|{loading: true}|{loading: "deferred"});

class JobNode extends React.Component<JobNodeProps&{path:JobPath}&JobNodeFuncs,{}> {
  handleOptionChange = (changeEvent:{target: {value: string}}) => {
    let textVal = changeEvent.target.value;
    let val:number|null;
    if(textVal === "none"){
      val = null;
    }else{
      val = parseInt(textVal);
    }
    let p = this.props;
    if(p.loading === false){
      let p2:JobNodeFuncsLoaded = p;
      p2.onSelectedRecipeChange(this.props.path, val);
    }else{
      throw "bad"
    }
  }
  handleQtyChange = (_:any, newQty:number) => {
    if(this.props.topLevel && !this.props.loading){
      this.props.onQtyChange(this.props.path, newQty)
    }else{
      throw "bad"
    }
  }
  handleRemove = () => {
    if(this.props.topLevel && !this.props.loading){
      this.props.onRemove(this.props.path)
    }else{
      throw "bad"
    }
  }
  handleFromInvQtyChange = (newQty:number) => {
    if(!this.props.loading){
      this.props.onFromInvQtyChange(this.props.path, newQty);
    }else{
      throw "bad"
    }
  }
  render() {
    let craftInfo = <>Loading...</>;
    if(!this.props.loading){
      let props:JobNodeFuncsLoaded = {...this.props};
      let jobNodeChildren = <></>;
      if(this.props.selectedRecipe != null) {
        let selRec = this.props.selectedRecipe;
        jobNodeChildren = <>
          {this.props.recipes[selRec].children.map((child, idx) => <div style={{display: "flex"}} key={idx}>
            <div className="job-qty"><b>{child.qty}x</b></div>
            <JobNode
              {...child.job}
              path={this.props.path.push([selRec, idx])}
              onSelectedRecipeChange={props.onSelectedRecipeChange}
              onFromInvQtyChange={props.onFromInvQtyChange} />
          </div>)}
        </>;
      }
      let recipeSelect = <>No recipes available</>;
      if(this.props.recipes.length > 0){
        // console.log(this.props.recipes);
        let selectedRecipe = this.props.selectedRecipe;
        recipeSelect = <>
        <label>
          <input
            name="recipe"
            value="none"
            type="radio"
            checked={selectedRecipe == null}
            onChange={this.handleOptionChange} /> None</label>
        {this.props.recipes.map((rec,idx) => <label key={rec.key}>
          <input
            name="recipe"
            value={idx}
            type="radio"
            checked={selectedRecipe === idx}
            onChange={this.handleOptionChange} />
          <img src={itemImg("minecraft:crafting_table", 0)} alt="Crafting" className="tiny-item" />
          &mdash;
          {rec.children.map((child,idx) => <React.Fragment key={idx}>
            <img src={itemImg(child.job.itemProps.name, child.job.itemProps.damage)} alt={child.job.itemProps.name} className="tiny-item" />
            x
            {child.qty}
          </React.Fragment>)}
        </label>)}</>
      }
      let craftCount = this.props.itemProps.count - this.props.invUseQty;
      craftInfo = <>
        <div className="job-craft-split">
          Of {this.props.itemProps.invQty}{this.props.itemProps.invQty == this.props.invAvailQty ? "" : ` (${this.props.invAvailQty} available)`}, use
          <ScrollableNumberInput
            disabled={this.props.qtyPinMode != "use"}
            value={this.props.invUseQty}
            onChange={this.handleFromInvQtyChange}
            passThru={{className: "inv-use-input"}} />
          and keep
          <ScrollableNumberInput
            disabled={this.props.qtyPinMode != "keep"}
            value={this.props.invKeepQty}
            onChange={this.handleFromInvQtyChange}
            passThru={{className: "inv-keep-input"}} />
          from inventory, crafting {craftCount}.
        </div>
        <form className="job-recipe-select">
          {recipeSelect}
        </form>
        <div className="job-node-children">
          {jobNodeChildren}
        </div>
      </>;
    }
          
    return (
      <div className="job-node">
        {this.props.topLevel ?
        <SelectableItem
          item={this.props.itemProps}
          onQtyChange={this.handleQtyChange}
          onRemove={this.handleRemove}
          error={this.props.errors.length > 0}
          mode="editable" />
        :
        <SelectableItem
          item={this.props.itemProps}
          error={this.props.errors.length > 0}
          mode="static" />}
        <div className="job-indent">{craftInfo}</div>
      </div>
    );
  }
}

type EditableSelectableItemProps = {
  mode: "editable",
  item: ItemWithCount&HasInvQty,
  error: boolean,
  onRemove: (item: ItemWithCount&HasInvQty) => void,
  onQtyChange: (item: ItemWithCount&HasInvQty, qty: number) => void
};

type SelectableItemProps = 
  {
    mode: "addable",
    item: Item&HasInvQty,
    error: boolean,
    onAdd: (item: Item&HasInvQty) => void
  }|EditableSelectableItemProps|{
    mode: "static",
    error: boolean,
    item: ItemWithCount&HasInvQty
  };

class SelectableItem extends React.Component<SelectableItemProps, {}> {
  onAddRemove() {
    if(this.props.mode === "addable"){
      this.props.onAdd(this.props.item);
    }else if(this.props.mode === "editable"){
      this.props.onRemove(this.props.item);
    }
  }
  onClick = (ev:any) => {
    this.onAddRemove();
  }

  onKey = (ev:{key: string}) => {
    //console.log(ev.key);
    switch (ev.key) {
      case "Enter":
      case "Space": {
        this.onAddRemove();
        break;
      }
    }
  }

  handleQtyChange = (newValue: number) => {
    if(this.props.mode === "editable"){
      this.props.onQtyChange(this.props.item, newValue)
    }else{
      throw "no"
    }
  }

  render() {
    let info = [];
    info.push(<span key="idname">{this.props.item.name}</span>);
    if (this.props.item.maxDamage > 0) {
      info.push(<span key="damage"> — D{this.props.item.damage}</span>);
    }
    let enchs;
    if ((enchs = this.props.item.enchantments)) {
      //let enchProps:(({full: string,shrt:string})[]) = [];
      let enchProps = [];
      for (let ench of enchs) {
        let enchData = enchantmentData.find(data => data[1] === ench.name);
        let shortcode;
        if (!enchData) {
          console.log(ench);
          shortcode = "??";
        } else {
          shortcode = enchData[0];
        }
        enchProps.push({full: ench.fullName, shrt: shortcode+ench.level});
      }
      enchProps.sort((a,b) => a.shrt < b.shrt ? -1 : a.shrt > b.shrt ? 1 : 0);
      let enchEls = enchProps.map(({full, shrt}) => <React.Fragment key={shrt}><abbr title={full}>{shrt}</abbr> </React.Fragment>);
      info.push(<span key="enchantments"> — {enchEls}</span>);
    }

    let qtyButtons = null;
    if (this.props.mode === "editable") {
      qtyButtons = <div style={{display: "inline-block"}}>
        <ScrollableNumberInput value={this.props.item.count} onChange={this.handleQtyChange} passThru={{style: {width:"5em"}}} />

        <button type="button">xS</button>
        <button type="button">+S</button>
        <button type="button">-S</button>
      </div>;
    } else if (this.props.mode === "static") {
      qtyButtons = <div style={{display: "inline-block"}}>
        x {this.props.item.count}
      </div>
    }
    return (
      <div className="iteminfo" style={{display: "flex", padding: "5px"}} id={`item-${this.props.item.id}`}>
        <div style={{display: "flex", flexDirection: "column"}}>
          <img 
            className="item-img"
            alt={this.props.item.displayName}
            style={{
              alignSelf: "start",
              width: "32px",
              height: "32px",
              imageRendering: "crisp-edges"
            }}
            src={itemImg(this.props.item.name, this.props.item.damage)} />
          {(this.props.mode === "editable" || this.props.mode === "addable") ?
            <button type="button" onClick={this.onClick} style={{border:"1px solid black", marginTop:"5px"}}>{this.props.mode === "editable" ? "-" : "+"}</button>
            : <></>
          }
        </div>
        <div style={{display: "flex", flexDirection: "column", flexGrow: 1, marginLeft:"5px"}}>
          <span>
            <b style={{color: this.props.error ? "red" : undefined}}>{this.props.item.displayName}</b>
            {qtyButtons}
          </span>
          <div>Have: <StackCount hideCount={false} count={this.props.item.invQty} stackSize={this.props.item.maxCount} /></div>
          <div>
            {info}
          </div>
        </div>
      </div>
    );
  }
}

function searchSql(query:string):Promise<(Item&HasInvQty)[]> {
  let where_clause = "";
  let sql_params:db.SqlValue[] = [];
  let param_idx = 0;
  if(query && query !== ""){
    let full = query;
    let [q, ...rest] = full.split(/\s*--?\s*/)
    for (let param of rest.flatMap(s => s.split(/\s+/))){
      let match:RegExpExecArray|null;
      let row;
      if ((match = /^d(\d+)$/i.exec(param)) !== null) {
        where_clause += `and item.damage = $${param_idx += 1} `;
        sql_params.push({ty: "int4", val: parseInt(match[1])});
      }else if (
        (match = /^([a-z][a-z])(\d?)$/.exec(param)) !== null && 
        //@ts-ignore
        (row = enchantmentData.find(r => r[0] === match[1]))
      ) {
        let search_json:{name: string, level?: number} = {name: row[1]};
        if (match[2] !== "") {
          search_json.level = parseInt(match[2]);
        }
        where_clause += `and item.fullMeta->'enchantments' @> $${param_idx += 1} `;
        sql_params.push({ty: "jsonb", val: [search_json]});
      }else if ((match = /^c$/i.exec(param)) !== null) {
        where_clause += `and exists (select * from crafting_recipe where result = item.id)) `
      }else{
        //ignore
      }
    }   
    q = q.replace(/^mc:/,"minecraft:")
    q = q.replace(/^cc:/,"computercraft:")
    q = q.replace(/\\/g,"\\\\")
    q = q.replace(/%/g,"\\%")
    q = q.replace(/_/g,"\\_")
    if(q !== "") {
      where_clause += `and (item.name ilike $${param_idx += 1} or item.fullMeta->>'displayName' ilike $${param_idx += 1}) `;
      sql_params.push({ty: "text", val: q + "%"});
      sql_params.push({ty: "text", val: "%" + q + "%"});
    }
  }
  where_clause += `and (coalesce(count.count,0) > 0 or exists (select * from crafting_recipe where result = item.id)) `
  let sql = "select item.id, item.fullMeta, item.damage, coalesce(count.count,0) as count from item left join (select item_id, sum(count) as count from stack group by item_id) count on count.item_id = item.id where true " + where_clause + "order by id limit 100";

  return db.sqlQuery(sql, sql_params).then((res:db.SqlValue[][]) => {
    return res.map(row => {
      let fullMeta = row[1].val as ItemMeta;
      let res:Item&HasInvQty = {invQty: row[3].val as number, damage: row[2].val as number, id: row[0].val as number, ...fullMeta};
      return res;
    })
  });
}

type AppState = {
  searchResults: (Item&HasInvQty)[],
  selected: OrderedMap<number, JobNodeProps>,
  searchText: string,
  searchN: number,
  outputChests: string[],
  selectedChest: string|null
};

let searchNAlloc = 1;

async function grabJobNodeRecipes(
  itemId:number,
  ancestorItems:Set<number> = Set(),
):Promise<{
  loading: false,
  invKeepQty: number,
  invAvailQty: number,
  invUseQty: number,
  qtyPinMode: "keep",
  recipes: RecipeProps[],
  selectedRecipe: number|null
}> {
  let res = await db.sqlQuery(
    "select id,result,result_count,"+ //idx 0,1,2
    "slot_1,"+ //idx 3
    "slot_2,"+
    "slot_3,"+
    "slot_4,"+
    "slot_5,"+
    "slot_6,"+
    "slot_7,"+
    "slot_8,"+
    "slot_9,"+ //idx 11
    "out_1,"+ //idx 12
    "out_2,"+
    "out_3,"+
    "out_4,"+
    "out_5,"+
    "out_6,"+
    "out_7,"+
    "out_8,"+
    "out_9 "+ //idx 20
    "from crafting_recipe where result = $1",
    [{ty:"int4", val: itemId}]
  );
  let recipes:RecipeProps[] = await Promise.all(res.filter(row => !ancestorItems.has(row[0].val as number)).map(async (row) => {
    let id = row[0].val as number;
    let result_id = row[1].val as number;
    let result_count = row[2].val as number;
    let slot_ids = row.slice(3, 12).map((sqlVal) => sqlVal.val as number|null);
    let out_ids = row.slice(12, 21).map((sqlVal) => sqlVal.val as number|null);

    let ids = [result_id];
    for(let id of slot_ids){
      if(id != null) ids.push(id);
    }
    for(let id of out_ids){
      if(id != null) ids.push(id);
    }
    
    let recipe_children:{qty: number, job: JobNodeProps&{topLevel: false}}[] = [];
    let slot_counts:Map<number, number> = new Map();
    for(let slot_id of slot_ids.filter(s => s != null) as number[]) {
      if(!slot_counts.has(slot_id)) {
        slot_counts.set(slot_id, 0);
      }
      slot_counts.set(slot_id, slot_counts.get(slot_id) as number + 1);
    }
    for(let [slot_id, count] of slot_counts.entries()){
      let ite = await getItem(slot_id);
      recipe_children.push({
        qty: count,
        job: {
          loading: "deferred",
          topLevel: false as false,
          itemProps: {...ite, count},
          errors: []
        }
      });
    }
    return {
      ty: "crafting" as "crafting",
      children: recipe_children,
      key: id,
      result_count
    };
  }));
  return {
    loading: false as false,
    invKeepQty: 1,
    qtyPinMode: "keep" as "keep",
    invUseQty: 0,
    invAvailQty: 0,
    recipes,
    selectedRecipe: recipes.length > 0 ? 0 : null
  }
}

async function submitJob(job: JobNodeProps&{loading: false}, parent: number){
  let job_dep_id = (await db.sqlQuery("insert into job_dep_graph (parent) values ($1) returning id", [{ty: "int4", val: parent}]))[0][0].val as number;
  let fromCraftQty = job.itemProps.count - job.invUseQty;
  console.log("fromCraftQty", fromCraftQty);
  if(job.selectedRecipe == null) return;
  let recipe = job.recipes[job.selectedRecipe as number];
  let craftTimes = Math.ceil(fromCraftQty/recipe.result_count);
  console.log(craftTimes);
  let stackSize = Math.min(...recipe.children.map(c => c.job.itemProps.maxCount));
  console.log(stackSize);
  let quotient = Math.floor(craftTimes/stackSize);
  console.log(quotient);
  let remainder = craftTimes%stackSize;
  for(let i=0;i<quotient;i++){
    await db.sqlQuery(
      "insert into job (parent, crafting_recipe_id, item_id, quantity) values ($1, $2, $3, $4)",
      [
        {ty: "int4", val: job_dep_id},
        {ty: "int4", val: recipe.key},
        {ty: "int4", val: job.itemProps.id},
        {ty: "int4", val: stackSize}
      ]
    )
  }
  if(remainder > 0){
    await db.sqlQuery(
      "insert into job (parent, crafting_recipe_id, item_id, quantity) values ($1, $2, $3, $4)",
      [
        {ty: "int4", val: job_dep_id},
        {ty: "int4", val: recipe.key},
        {ty: "int4", val: job.itemProps.id},
        {ty: "int4", val: remainder}
      ]
    )
  }
  for(let {job} of recipe.children) {
    await submitJob(job as JobNodeProps&{loading: false}, job_dep_id);
  }
}

async function submitJobs(jobs: OrderedMap<number, JobNodeProps&{loading: false}>, out: string|null){
  console.log("out is", out);
  await db.sqlQuery("START TRANSACTION",[]);
  //await db.sqlQuery("lock job",[]);
  await db.sqlQuery("lock job_dep_graph",[]);
  let rootNode = (await db.sqlQuery("insert into job_dep_graph (parent) VALUES (NULL) returning id", []))[0][0].val as number;
  for(let [_, job] of jobs.entries()){
    await submitJob(job, rootNode);
    if(out != null){
      let stackSize = job.itemProps.maxCount;
      let quotient = Math.floor(job.itemProps.count/stackSize);
      let remainder = job.itemProps.count%stackSize
      for(let i=0;i<quotient;i++){
        await db.sqlQuery(
          "insert into job (parent, chest_computer, chest_name, item_id, quantity) values ($1, $2, $3, $4, $5)",
          [
            {ty: "int4", val: rootNode},
            {ty: "int4", val: 55},
            {ty: "text", val: out},
            {ty: "int4", val: job.itemProps.id},
            {ty: "int4", val: stackSize}
          ]
        )
      }  
      if(remainder > 0){
        await db.sqlQuery(
          "insert into job (parent, chest_computer, chest_name, item_id, quantity) values ($1, $2, $3, $4, $5)",
          [
            {ty: "int4", val: rootNode},
            {ty: "int4", val: 55},
            {ty: "text", val: out},
            {ty: "int4", val: job.itemProps.id},
            {ty: "int4", val: remainder}
          ]
        )
      }
    }
    
  }
  await db.sqlQuery("COMMIT",[]);
}

type InventoryThing = Map<number,number>;

async function getQty(it:InventoryThing, itemId:number):Promise<number>{
  if(it.has(itemId)){
    return it.get(itemId)!;
  }else{
    return (await getItem(itemId)).invQty;
  }
}

class App extends React.Component<{},AppState> {
  state:AppState = {
    searchResults: [],
    selected: OrderedMap<number, JobNodeProps>(),
    searchText: "",
    searchN: 0,
    outputChests: [],
    selectedChest: null
  };
  submitJob = () => {
    submitJobs(this.state.selected as OrderedMap<number, JobNodeProps&{loading: false}>, this.state.selectedChest);
    this.setState({selected: OrderedMap()})
  }
  async recomputeThings<T extends boolean>(
    path: JobPath,
    ancestorItems: Set<number>,
    origJob: JobNodeProps&{topLevel: T},
    inventoryThing: InventoryThing
  ):Promise<JobNodeProps&{topLevel: T}> {
    let job = cloneDeep(origJob);
    let errors:string[] = [];
    let fam = ancestorItems.add(job.itemProps.id);
    if(job.loading === false){
      job.invAvailQty = await getQty(inventoryThing, job.itemProps.id)!;
      let actualKeepQty;
      let actualUseQty;
      if(job.qtyPinMode == "keep")
      {
        actualKeepQty = Math.min(job.invKeepQty, job.invAvailQty);
        actualUseQty = Math.min(job.invAvailQty - actualKeepQty, job.itemProps.count);
        job.invUseQty = actualUseQty;
      }
      else
      {
        actualUseQty = Math.min(job.invUseQty, job.invAvailQty, job.itemProps.count);
        actualKeepQty = job.invAvailQty - actualUseQty;
        job.invKeepQty = actualKeepQty;
      }
      inventoryThing.set(job.itemProps.id, job.invAvailQty - actualUseQty);
      if(job.invUseQty < 0 ) errors.push("Use qty must be nonnegative");
      if(job.invKeepQty < 0) errors.push("Keep qty must be nonnegative");
      let craftQty = job.itemProps.count - actualUseQty;
      if(craftQty > 0 && job.selectedRecipe == null){
        errors.push("Set to craft, but no recipe selected.")
      }
      if(job.selectedRecipe != null){
        let rec = job.recipes[job.selectedRecipe];
        for(let [idx,child] of rec.children.entries()){
          child.job.itemProps.count = child.qty * Math.ceil(craftQty/rec.result_count);
          let newJob = await this.recomputeThings(
            path.push([job.selectedRecipe, idx]),
            fam,
            child.job,
            inventoryThing
          );
          if(newJob.errors.length > 0){
            errors.push("Child job has errors.");
          }
          child.job = newJob;
        }
      }
    }else{
      let id = job.itemProps.id;
      grabJobNodeRecipes(id, ancestorItems).then((props) => {
        this.updateJob(path, (j) => {
          //return this.recomputeThings(path, fam, {...j, ...props}, inventoryThing);
          return {...j, ...props};
        });
      });
    }
    return job;
  }
  // jobNodeAddValidation<T extends boolean>(
  //   path: JobPath,
  //   ancestors: Set<number>,
  //   job: (JobNodeProps&{topLevel: T}),
  //   newCount?: number
  // ): (JobNodeProps&{topLevel: T}) {
  //   let errors:string[] = [];
  //   let fam = ancestors.add(job.itemProps.id);
  //   if(job.loading === false){
  //     if(newCount != null){
  //       let oldCount = job.itemProps.count;
  //       job.itemProps.count = newCount;
  //       //job.invUseQty = Math.min(job.itemProps.invQty, newCount);
  //     }
  //     if(job.qtyPinMode == "keep"){
  //       job.invUseQty = Math.min(job.invAvailQty - job.invKeepQty, job.itemProps.count);
  //     }else if(job.qtyPinMode == "use"){
  //       job.invKeepQty = job.invAvailQty - job.invUseQty;
  //     }
  //     if(job.itemProps.count < job.invUseQty){
  //       errors.push("Grabbing more from inventory than is needed.")
  //     }
  //     if(job.topLevel){
  //       if(job.itemProps.count <= 0){
  //         errors.push("count must be positive.")
  //       }
  //     }
  //     if(job.invUseQty < 0){
  //       errors.push("'use' quantity must be positive or 0.");
  //     }
  //     if(job.invUseQty > job.itemProps.invQty){
  //       errors.push("Trying to grab more from inventory then is available.");
  //     }
  //     if(job.itemProps.count > job.invUseQty && job.selectedRecipe == null){
  //       errors.push("Set to craft, but no recipe selected.")
  //     }
  //     if(job.selectedRecipe != null){
  //       let rec = job.recipes[job.selectedRecipe];
  //       for(let [idx,child] of rec.children.entries()){
  //         let newJob = this.jobNodeAddValidation(
  //           path.push([job.selectedRecipe, idx]),
  //           fam,
  //           child.job,
  //           /*newCount == null ? undefined : */child.qty * Math.ceil((job.itemProps.count-job.invUseQty)/rec.result_count)
  //         );
  //         if(newJob.errors.length > 0){
  //           errors.push("Child job has errors.");
  //         }
  //         child.job = newJob;
  //       }
  //     }
  //   }else{
  //     let id = job.itemProps.id;
  //     grabJobNodeRecipes(id).then((props) => {
  //       this.updateJob(path, (j) => {
  //         //TODO: auto-select recipe?
  //         return this.jobNodeAddValidation(path, fam, {...j, ...props});
  //       })
  //       // this.setState((state) => {
  //       //   let old:JobNodeProps|undefined = state.selected.get(id);
  //       //   if(old == null) throw "bad";
  //       //   let newUnvalidated:JobNodeProps = {...old, ...props};
  //       //   let newJob = this.jobNodeAddValidation(path, newUnvalidated)
  //       //   return {selected: state.selected.set(id, newJob)}
  //       // })
  //     })
  //   }
  //   return {
  //     ...job,
  //     errors
  //   }
  // }
  updateJob(path: JobPath, f:(j:JobNodeProps) => JobNodeProps){
    let state = this.state;
    let topId = path.first() as number;
    let lowerPath = path.shift() as List<[number,number]>;
    let topRef:{job: JobNodeProps} = {job: cloneDeep(state.selected.get(topId)) as JobNodeProps};
    let job = topRef.job;
    let ref = topRef;
    for(let [recipeIdx, childIdx] of lowerPath){
      ref = (job as JobNodeProps&{loading:false}).recipes[recipeIdx].children[childIdx];
      job = ref.job;
    }
    //let oldCount = job.itemProps.count;
    ref.job = f(cloneDeep(job) as JobNodeProps);
    let inventoryThing:InventoryThing = new Map();
    // let setOfPromises:Promise<[number, JobNodeProps]>[] = [... state.selected.entrySeq().map(async ([key, val]) => 
    //   {let thing:[number, JobNodeProps] = [key, await this.recomputeThings(
    //     List([key]),
    //     Set(),
    //     key == topId ? topRef.job : val,
    //     inventoryThing
    //   )];return thing}
    // )];
    // //let setOfThings:[number,JobNodeProps][] = await Promise.all(setOfPromises);
    // let func = async function<T> (sop:Promise<T>[]):Promise<T[]> {
    //   let res = [];
    //   for(const f of sop){
    //     res.push(await f);
    //   }
    //   return res;
    // }
    let func = async (selected:OrderedMap<number,JobNodeProps>):Promise<[number,JobNodeProps][]> => {
      let res:[number,JobNodeProps][] = [];
      for( const [key,val] of selected ){
        res.push([key, await this.recomputeThings(
          List([key]),
          Set(),
          key == topId ? topRef.job : val,
          inventoryThing
        )]);
      }
      return res
    }
    func(this.state.selected).then(setOfThings => {
      this.setState(state => {
        return {selected: OrderedMap(setOfThings)}
      })
    })
    // return {
    //   selected: OrderedMap(Promise.all())
    //   // selected: state.selected.set(
    //   //   topId,
    //   //   this.recomputeThings(
    //   //     List([topId]),
    //   //     Set(),
    //   //     topRef.job,
    //   //     oldCount == job.itemProps.count ? undefined : job.itemProps.count
    //   //   )
    //   // )
    // }
  }
  recompute(){
    let inventoryThing:InventoryThing = new Map();
    let func = async (selected:OrderedMap<number,JobNodeProps>):Promise<[number,JobNodeProps][]> => {
      let res:[number,JobNodeProps][] = [];
      for( const [key,val] of selected ){
        res.push([key, await this.recomputeThings(
          List([key]),
          Set(),
          val,
          inventoryThing
        )]);
      }
      return res
    }
    func(this.state.selected).then(setOfThings => {
      this.setState(state => {
        return {selected: OrderedMap(setOfThings)}
      })
    })
  }
  componentDidMount(){
    console.log("mounting run");
    db.sqlQuery("select name from chest where ty='output'",[]).then((res) => {
      let oc = res.map((row) => row[0].val as string)
      this.setState({outputChests: oc, selectedChest: oc[0] || null});
    })
    this.onSearch({target: {value: "mc:stick"}});
  }
  onSearch = (ev:{target: {value: string}}) => {
    console.log("onSearch");
    let allocd = searchNAlloc;
    searchNAlloc += 1;
    let searchText = ev.target.value;
    this.setState({searchText});
    searchSql(searchText).then((res: (Item&HasInvQty)[]) => {
      this.setState((state) => (state.searchN < allocd ? {searchN: allocd, searchResults: res} : null));
    });
  }
  onAdd = (item: Item&HasInvQty) => {
    let props:JobNodeProps = {
      itemProps: {...item, count: 1},
      topLevel: true,
      loading: true,
      errors: []
    };
    this.state.selected = this.state.selected.set(item.id, props);
    this.recompute();
  }
  onRemove = (item: Item) => {
    this.setState((state) => ({selected: state.selected.delete(item.id)}));
  }
  handleSelectedRecipeChange = (path:JobPath, idx:number|null) => {
    this.updateJob(path, (j) => ({...j, selectedRecipe: idx}));
  }
  handleRemove = (path: JobPath) => {
    this.setState((state) => {
      return {selected: state.selected.remove(path.first() as number)}
    });
  }
  handleQtyChange = (path: JobPath, newQty: number) => {
    this.updateJob(path, (j) => ({...j, itemProps: {...j.itemProps, count: newQty}}));
  }
  handleFromInvQtyChange = (path: JobPath, newQty: number) => {
    this.updateJob(path, (j) => ({...j, fromInvQty: newQty}));
  }
  render(){
    return (
      <div id="app">
        <div id="in-progress">
          
        </div>
        <hr />
        <div id="job-editor">
          <div id="selected-jobs">
            {this.state.selected.entrySeq().map((a:[number, JobNodeProps]) => 
              <JobNode
                key={a[0]}
                {...a[1]}
                path={List([a[0]])}
                onSelectedRecipeChange={this.handleSelectedRecipeChange}
                onRemove={this.handleRemove}
                onQtyChange={this.handleQtyChange}
                onFromInvQtyChange={this.handleFromInvQtyChange} />
            ).toArray()}
          </div>
          <select
            onChange={(ev) => this.setState({selectedChest: ev.target.value === "none" ? null : ev.target.value})}>
            <option
              value="none"
              selected={this.state.selectedChest === null}>
              None/Keep in inventory
            </option>
            {
              this.state.outputChests.map((cname) => 
                <option
                  key={cname}
                  value={cname}
                  selected={this.state.selectedChest === cname}>
                  {cname}
                </option>
              )
            }
          </select>
          <button type="button" onClick={this.submitJob}>Go</button>
        </div>
        <hr />
        <div><input type="text" placeholder="search" style={{width: "500px", maxWidth: "100%"}} value={this.state.searchText} onChange={this.onSearch} /></div>
        <div id="search-results">
          {this.state.searchResults.map(s => {
            if (this.state.selected.has(s.id)){
              return null
            } else {
              return <SelectableItem key={s.id} item={s} onAdd={this.onAdd} mode="addable" error={false}/>
            }
          })}
          <hr/>
          <span id="search-results-more-indicator">
            {this.state.searchResults.length < 100 ? "That's all there is." : "Only showing first 100 results." }
          </span>
        </div>
      </div>
    );
  }
}

export default App;
