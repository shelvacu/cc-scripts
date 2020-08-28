import React from 'react';
import { OrderedMap } from 'immutable';
//import logo from './logo.svg';
//import './App.css';
import * as blockdata from './blockdata';
import enchantmentData from './enchantmentData';
import * as db from './database';

const ItemsCache = new Map<number,Item>();

function preloadItemsCache(ids: number[]):Promise<void> {
  return db.sqlQuery("select fullMeta, damage, id from item where id in (" + ids.join(",") + ");").then((rows) => {
    for(let row of rows) {
      let item = {
        fullMeta: row[0].val as ItemMeta,
        damage: row[1].val as number,
        id: row[2].val as number
      };
      ItemsCache.set(item.id, item);
    }
    return;
  });
}

function getItem(id:number):Promise<Item> {
  return new Promise(function(suc, fail) {
    if (ItemsCache.has(id)) {
      suc(ItemsCache.get(id));
    } else {
      preloadItemsCache([id]);
      suc(ItemsCache.get(id));
    }
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

class ScrollableNumberInput extends React.Component<{value: number, onChange: (newValue: number) => any, passThru?: object}, {}> {
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
    let innerProps = {
      type: "number",
      value: this.props.value,
      onScroll: this.scroll,
      onChange: this.onChange,
      ...(this.props.passThru || {})
    };
    // return React.createElement("input", innerProps);
    return <input {...innerProps} />
  }
}

// class ScrollableTestWrapper extends React.Component<{}, {value: number|null}> {
//   state = {value: 0};
// 
//   onChange = (value: number|null) => this.setState({value});
//   
//   render() {
//     return <ScrollableNumberInput value={this.state.value} onChange={this.onChange} />
//   }
// }

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
  fullMeta: ItemMeta,
  damage: number,
  id: number
};

type ItemWithCount = Item & {count: number};

type EditableSelectableItemProps = {
  editMode: true,
  item: ItemWithCount,
  quantity: number,
  onRemove: (item: ItemWithCount) => void,
  onQtyChange: (item: ItemWithCount, qty: number) => void
};

type SelectableItemProps = 
  {
    editMode?: false,
    item: ItemWithCount,
    onAdd: (item: ItemWithCount) => void
  }|EditableSelectableItemProps;

class SelectableItem extends React.Component<SelectableItemProps, {}> {
  onAddRemove() {
    let func = this.props.editMode ? this.props.onRemove : this.props.onAdd;
    func(this.props.item);
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

  render() {
    let info = [];
    info.push(<span key="idname">{this.props.item.fullMeta.name}</span>);
    if (this.props.item.fullMeta.maxDamage > 0) {
      info.push(<span key="damage"> — D{this.props.item.damage}</span>);
    }
    let enchs;
    if ((enchs = this.props.item.fullMeta.enchantments)) {
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
    if (this.props.editMode) {
      qtyButtons = <div style={{display: "inline-block"}}>
        <ScrollableNumberInput value={this.props.quantity} onChange={()=>1} passThru={{style: {width:"5em"}}} />

        <button type="button">xS</button>
        <button type="button">+S</button>
        <button type="button">-S</button>
      </div>;
    }
    return (
      <div className="iteminfo" style={{display: "flex", padding: "5px"}} id={`item-${this.props.item.id}`}>
        <div style={{display: "flex", flexDirection: "column"}}>
          <img 
            className="item-img"
            alt={this.props.item.fullMeta.displayName}
            style={{
              alignSelf: "start",
              width: "32px",
              height: "32px",
              imageRendering: "crisp-edges"
            }}
            src={itemImg(this.props.item.fullMeta.name, this.props.item.damage)} />
          <button type="button" onClick={this.onClick} style={{border:"1px solid black", marginTop:"5px"}}>{this.props.editMode ? "-" : "+"}</button>
        </div>
        <div style={{display: "flex", flexDirection: "column", flexGrow: 1, marginLeft:"5px"}}>
          <span>
            <b>{this.props.item.fullMeta.displayName}</b>
            {qtyButtons}
          </span>
          <div>Have: <StackCount hideCount={false} count={this.props.item.count} stackSize={this.props.item.fullMeta.maxCount} /></div>
          <div>
            {info}
          </div>
        </div>
      </div>
    );
  }
}

type RecipeProps = {
  ty: "crafting",
  children: {qty: number, job: JobNodeProps}[],
  key: string
};

type JobNodeProps =
  {itemProps: EditableSelectableItemProps} & ({
    loading: false,
    invQty: number, //the number of items to pull from inventory, rather than crafting them.
    recipes: RecipeProps[],
    selectedRecipe: number|null
    //children: [number, JobNodeProps][]
  }|{loading: true});

class JobNode extends React.Component<JobNodeProps,{}> {
  render() {
    let craftInfo = <>Loading...</>;
    if(!this.props.loading){
      let jobNodeChildren = <></>;
      if(this.props.selectedRecipe != null) {
        jobNodeChildren = <>
          {this.props.recipes[this.props.selectedRecipe].children.map((child) => <div style={{display: "flex"}}>
            <div className="job-qty"><b>{child.qty}x</b></div>
            <JobNode {...child.job} />
          </div>)}
        </>;
      }
      let recipeSelect = <>No recipes available</>;
      if(this.props.recipes.length > 0){
        recipeSelect = <>{this.props.recipes.map((rec,idx) => <label key={rec.key}>
          <input name="recipe" value={idx} type="radio" />
          <img src={itemImg("minecraft:crafting_table", 0)} alt="Crafting" />
          &mdash;
          {rec.children.map((child,idx) => <React.Fragment key={idx}>
            <img src={itemImg(child.job.itemProps.item.fullMeta.name, child.job.itemProps.item.damage)} alt={child.job.itemProps.item.fullMeta.name} />
            x
            {child.qty}
          </React.Fragment>)}
        </label>)}</>
      }
      let craftCount = this.props.itemProps.item.count - this.props.invQty;
      craftInfo = <>
        <div className="job-craft-split">
          <ScrollableNumberInput value={this.props.invQty} onChange={()=>1} /> from inventory, {craftCount} from crafting.
        </div>
        <form className="job-recipe-select">
          
        </form>
        <div className="job-node-children">
          {jobNodeChildren}
        </div>
      </>;
    }
          
    return (
      <div className="job-node">
        <SelectableItem {...this.props.itemProps} />
        {craftInfo}
      </div>
    );
  }
}

function searchSql(query:string):Promise<ItemWithCount[]> {
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
  let sql = "select item.id, item.fullMeta, item.damage, count.count from item, (select item_id, sum(count) as count from stack group by item_id) count where count.item_id = item.id " + where_clause + "order by id limit 100";

  //console.log(sql, sql_params);
  return db.sqlQuery(sql, sql_params).then((res:db.SqlValue[][]) => {
    return res.map(row => {
      let fullMeta = row[1].val as ItemMeta;
      return {id: row[0].val as number, fullMeta, damage: row[2].val as number, count: row[3].val as number}
    })
  });
}
/*
type JobNodeState = {
  item: Item,
*/

type AppState = {
  searchResults: Item[],
  selected: OrderedMap<number, JobNodeProps>,
  searchText: string,
  searchN: number
};

let searchNAlloc = 1;

class App extends React.Component<{},AppState> {
  state:AppState = {
    searchResults: [],
    selected: OrderedMap<number, JobNodeProps>(),
    searchText: "",
    searchN: 0
  };
  componentDidMount(){
    console.log("mounting run");
    this.onSearch({target: {value: ""}});
  }
  onSearch = (ev:{target: {value: string}}) => {
    console.log("onSearch");
    let allocd = searchNAlloc;
    searchNAlloc += 1;
    let searchText = ev.target.value;
    this.setState({searchText});
    searchSql(searchText).then((res: Item[]) => {
      this.setState((state) => (state.searchN < allocd ? {searchN: allocd, searchResults: res} : null));
    });
  }
  onAdd = (item: Item) => {
    this.setState((state) => {
      let props:JobNodeProps = {
        itemProps: {
          editMode: true,
          item,
          quantity: 1,
          onRemove: this.onRemove,
          onQtyChange: ()=>1
        },
        loading: true
      };
      return {
        selected: state.selected.set(item.id, props)
      }
    });
    db.sqlQuery(
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
      [{ty:"int4", val: item.id}]
    ).then((res) => {
      let recipes = res.map((row) => {
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
        preloadItemsCache(ids);
        let result:Item = ItemsCache.get(result_id);
        let slots:(Item|null)[] = slot_ids.map((id) => id == null ? null : ItemsCache.get(id));
        let outs: (Item|null)[] =  out_ids.map((id) => id == null ? null : ItemsCache.get(id));
        
    });
  }
  onRemove = (item: Item) => {
    this.setState((state) => ({selected: state.selected.delete(item.id)}));
  }
  render(){
    return (
      <div id="app">
        <div id="in-progress">
          
        </div>
        <hr />
        <div id="job-editor">
          <div id="selected-jobs">
            {this.state.selected.entrySeq().map((a:[number, JobNodeProps]) => <JobNode key={a[0]} {...a[1]} />).toArray()}
          </div>
          <button type="button">Go</button>
        </div>
        <hr />
        <div><input type="text" placeholder="search" style={{width: "500px", maxWidth: "100%"}} value={this.state.searchText} onChange={this.onSearch} /></div>
        <div id="search-results">
          {this.state.searchResults.map(s => {
            if (this.state.selected.has(s.id)){
              return null
            } else {
              return <SelectableItem key={s.id} item={s} onAdd={this.onAdd} />
            }
          })}
        </div>
      </div>
    );
  }
}
// function App() {
//   const item = {
//     count: 200,
//     damage: 0,
//     displayName: "String",
//     fullMeta: {
//       count: 1,
//       damage: 0,
//       displayName: "String",
//       maxCount: 64,
//       maxDamage: 0,
//       name: "minecraft:string",
//       //ores: {...}
//       rawName: "item.string"
//     },
//     id: 119
//   };
//   return (
//     <div className="App">
//       <SelectableItem item={item} />
//       <ScrollableTestWrapper />
//     </div>
//   );
// }

export default App;
