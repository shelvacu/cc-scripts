import React from 'react';
import { OrderedMap } from 'immutable';
//import logo from './logo.svg';
//import './App.css';
import * as blockdata from './blockdata';
import enchantmentData from './enchantmentData';
import * as db from './database';

const ItemsCache = new Map<number,Item>();

function preloadItemsCache(ids: number[]):Promise<void> {
  console.log(ids);
  return db.sqlQuery("select fullMeta, damage, id from item where id in (" + ids.join(",") + ");",[]).then((rows) => {
    for(let row of rows) {
      let item = {
        damage: row[1].val as number,
        id: row[2].val as number,
        ...(row[0].val as ItemMeta)
      };
      ItemsCache.set(item.id, item);
    }
    return;
  });
}

function getItem(id:number):Promise<Item> {
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
    return <input type="number" value={this.props.value} onScroll={this.scroll} onChange={this.onChange} {...(this.props.passThru || {})} />
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
  damage: number,
  id: number
} & ItemMeta;

type ItemWithCount = {count: number} & Item;

// type ItemWithCount = Item & {count: number};

// type EditableSelectableItemProps = {
//   editMode: true,
//   item: ItemWithCount,
//   quantity: number,
//   onRemove: (item: ItemWithCount) => void,
//   onQtyChange: (item: ItemWithCount, qty: number) => void
// };
// 
// type SelectableItemProps = 
//   {
//     editMode?: false,
//     item: Item,
//     count: number,
//     onAdd: (item: [Item, number]) => void
//   }|EditableSelectableItemProps;

// type ItemComponentProps = {
//   item: ItemWithCount,
//   have: number,
//   children: React.Component[],
//   buttonIsAdd: boolean,
//   onClick: (me: ItemComponentProps) => void
// };

// class ItemComponent extends React.Component<ItemComponentProps, {}> {
//   onAddRemove() {
//     this.props.onClick(this.props);
//   }
//   onClick = (ev:any) => {
//     this.onAddRemove();
//   }

//   onKey = (ev:{key: string}) => {
//     //console.log(ev.key);
//     switch (ev.key) {
//       case "Enter":
//       case "Space": {
//         this.onAddRemove();
//         break;
//       }
//     }
//   }

//   render() {
//     let info = [];
//     info.push(<span key="idname">{this.props.item.name}</span>);
//     if (this.props.item.maxDamage > 0) {
//       info.push(<span key="damage"> — D{this.props.item.damage}</span>);
//     }
//     let enchs;
//     if ((enchs = this.props.item.enchantments)) {
//       //let enchProps:(({full: string,shrt:string})[]) = [];
//       let enchProps = [];
//       for (let ench of enchs) {
//         let enchData = enchantmentData.find(data => data[1] === ench.name);
//         let shortcode;
//         if (!enchData) {
//           console.log(ench);
//           shortcode = "??";
//         } else {
//           shortcode = enchData[0];
//         }
//         enchProps.push({full: ench.fullName, shrt: shortcode+ench.level});
//       }
//       enchProps.sort((a,b) => a.shrt < b.shrt ? -1 : a.shrt > b.shrt ? 1 : 0);
//       let enchEls = enchProps.map(({full, shrt}) => <React.Fragment key={shrt}><abbr title={full}>{shrt}</abbr> </React.Fragment>);
//       info.push(<span key="enchantments"> — {enchEls}</span>);
//     }

//     let qtyButtons = null;
//     /* if (this.props.editMode) {
//       qtyButtons = <div style={{display: "inline-block"}}>
//         <ScrollableNumberInput value={this.props.quantity} onChange={()=>1} passThru={{style: {width:"5em"}}} />

//         <button type="button">xS</button>
//         <button type="button">+S</button>
//         <button type="button">-S</button>
//       </div>;
//     } */
//     return (
//       <div className="iteminfo" style={{display: "flex", padding: "5px"}} id={`item-${this.props.item.id}`}>
//         <div style={{display: "flex", flexDirection: "column"}}>
//           <img 
//             className="item-img"
//             alt=""
//             style={{
//               alignSelf: "start",
//               width: "32px",
//               height: "32px",
//               imageRendering: "crisp-edges"
//             }}
//             src={itemImg(this.props.item.name, this.props.item.damage)} />
//           <button type="button" onClick={this.onClick} style={{border:"1px solid black", marginTop:"5px"}}>{this.props.buttonIsAdd ? "-" : "+"}</button>
//         </div>
//         <div style={{display: "flex", flexDirection: "column", flexGrow: 1, marginLeft:"5px"}}>
//           <span>
//             <b>{this.props.item.displayName}</b>
//             /*{qtyButtons}*/
//           </span>
//           <div>Have: <StackCount hideCount={false} count={this.props.item.count} stackSize={this.props.item.maxCount} /></div>
//           <div>
//             {info}
//           </div>
//           {this.props.children}
//         </div>
//       </div>
//     );
//   }
// }

type RecipeProps = {
  ty: "crafting",
  children: {qty: number, job: JobNodeProps}[],
  key: number,
  result_count: number
};

type JobNodeProps =
  {itemProps: ItemWithCount, topLevel: boolean} & ({
    loading: false,
    invQty: number, //the number of items to pull from inventory, rather than crafting them.
    recipes: RecipeProps[],
    selectedRecipe: number|null
    //children: [number, JobNodeProps][]
  }|{loading: true}|{loading: "deferred"});

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
        console.log(this.props.recipes);
        recipeSelect = <>
        <label><input name="recipe" value={-1} type="radio" /> None</label>
        {this.props.recipes.map((rec,idx) => <label key={rec.key}>
          <input name="recipe" value={idx} type="radio" />
          <img src={itemImg("minecraft:crafting_table", 0)} alt="Crafting" className="tiny-item"/>
          &mdash;
          {rec.children.map((child,idx) => <React.Fragment key={idx}>
            <img src={itemImg(child.job.itemProps.name, child.job.itemProps.damage)} alt={child.job.itemProps.name} className="tiny-item" />
            x
            {child.qty}
          </React.Fragment>)}
        </label>)}</>
      }
      let craftCount = this.props.itemProps.count - this.props.invQty;
      craftInfo = <>
        <div className="job-craft-split">
          <ScrollableNumberInput value={this.props.invQty} onChange={()=>1} passThru={{className: "from-inv-input"}}/> from inventory, {craftCount} from crafting.
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
          onQtyChange={()=>null}
          onRemove={()=>null}
          mode="editable" />
        :
        <SelectableItem
          item={this.props.itemProps}
          mode="static" />}
        <div className="job-indent">{craftInfo}</div>
      </div>
    );
  }
}

type EditableSelectableItemProps = {
  mode: "editable",
  item: ItemWithCount,
  onRemove: (item: ItemWithCount) => void,
  onQtyChange: (item: ItemWithCount, qty: number) => void
};

type SelectableItemProps = 
  {
    mode: "addable",
    item: ItemWithCount,
    onAdd: (item: ItemWithCount) => void
  }|EditableSelectableItemProps|{
    mode: "static",
    item: ItemWithCount
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
        <ScrollableNumberInput value={this.props.item.count} onChange={()=>1} passThru={{style: {width:"5em"}}} />

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
            <b>{this.props.item.displayName}</b>
            {qtyButtons}
          </span>
          <div>Have: <StackCount hideCount={false} count={this.props.item.count} stackSize={this.props.item.maxCount} /></div>
          <div>
            {info}
          </div>
        </div>
      </div>
    );
  }
}

// type SelectableItemProps = {
//   item: ItemWithCount
// } & ({quantityEditable: true, onChange: (newValue: number)=>any}|{quantityEditable: false});

// class SelectableItem extends React.Component<SelectableItemProps,{}> {
//   render() {
//     return (
//       <div id={"item-" + this.props.item.id}>
//         <div className="flex-col">
//           <div className="item-quantity">
//             {this.props.quantityEditable ? <ScrollableNumberInput value={this.props.item.count} onChange={this.props.onChange}/> : <>{this.props.item.count}</>}
//           </div>
//         </div>
//         <img src={itemImg(this.props.item.name, this.props.item.damage)} className="item-img" />
//         <div className="flex-col" style={{flexGrow: 1}}>

//         </div>
//       </div>
//     );
//   }
// }

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
      return {count: row[3].val, damage: row[2].val, id: row[0].val, ...fullMeta};
      //return {id: row[0].val as number, fullMeta, damage: row[2].val as number, count: row[3].val as number}
    })
  });
}
/*
type JobNodeState = {
  item: Item,
*/

type AppState = {
  searchResults: ItemWithCount[],
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
    this.onSearch({target: {value: "oak wood plan"}});
  }
  onSearch = (ev:{target: {value: string}}) => {
    console.log("onSearch");
    let allocd = searchNAlloc;
    searchNAlloc += 1;
    let searchText = ev.target.value;
    this.setState({searchText});
    searchSql(searchText).then((res: ItemWithCount[]) => {
      this.setState((state) => (state.searchN < allocd ? {searchN: allocd, searchResults: res} : null));
    });
  }
  onAdd = (item: Item) => {
    this.setState((state) => {
      let props:JobNodeProps = {
        /*itemProps: {
          //editMode: true,
          item,
          quantity: 1,
          onRemove: this.onRemove,
          onQtyChange: ()=>1
        },*/
        itemProps: {...item, count: 1},
        topLevel: true,
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
      let recipes:RecipeProps[] = res.map((row) => {
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
        // let result:Item = ItemsCache.get(result_id) as Item;
        // let slots:(Item|null)[] = slot_ids.map((id) => id == null ? null : ItemsCache.get(id) as Item);
        // let outs: (Item|null)[] =  out_ids.map((id) => id == null ? null : ItemsCache.get(id) as Item);
        
        let recipe_children:{qty: number, job: JobNodeProps}[] = [];
        let slot_counts:Map<number, number> = new Map();
        for(let slot_id of slot_ids.filter(s => s != null) as number[]) {
          if(!slot_counts.has(slot_id)) {
            slot_counts.set(slot_id, 0);
          }
          slot_counts.set(slot_id, slot_counts.get(slot_id) as number + 1);
        }
        for(let [slot_id, count] of slot_counts.entries()){
          getItem(slot_id).then((ite) => {
            recipe_children.push({
              qty: count,
              job: {
                loading: "deferred",
                topLevel: false,
                itemProps: {...ite, count}
              }
            });
          })
        }
        return {
          ty: "crafting",
          children: recipe_children,
          key: id,
          result_count
        };
      });

      getCount(item.id).then((invQty) => {
        this.setState((state) => {
          let oldProps = state.selected.get(item.id);
          if(!oldProps) throw "blarg";
          let newProps = {...oldProps, loading: false as false, invQty, recipes, selectedRecipe: null};
          console.log(newProps);
          return {selected: state.selected.set(item.id, newProps)};
        });
      })
      
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
              return <SelectableItem key={s.id} item={s} onAdd={this.onAdd} mode="addable"/>
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
