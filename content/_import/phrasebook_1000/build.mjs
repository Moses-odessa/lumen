import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { FileBlob, SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const here = path.dirname(fileURLToPath(import.meta.url));
const template = 'C:/Users/moses/Downloads/Core_Phrases_A1_B2_Template.xlsx';
const outDir = 'D:/myprojects/lumen/outputs/01a0763e-f3de-7961-b039-bad65add2953';
const supportDir = path.join(here, 'qa');
await fs.mkdir(supportDir, { recursive: true });

if (process.argv.includes('--inspect-template')) {
  const original = await SpreadsheetFile.importXlsx(await FileBlob.load(template));
  console.log((await original.inspect({kind:'table',range:'Core_Phrases_A1_B2!A1:G7',tableMaxRows:7,tableMaxCols:7,maxChars:3500})).ndjson);
  const preview = await original.render({sheetName:'Core_Phrases_A1_B2',range:'A1:G7',scale:1,format:'png'});
  await fs.writeFile(path.join(supportDir,'template.png'),new Uint8Array(await preview.arrayBuffer()));
  process.exit(0);
}

const modules = [];
for (const level of ['A0','A1','A2','B1','B2']) {
  const {default: data} = await import(`./${level}.mjs`);
  modules.push(...data);
}

const levels = ['A0','A1','A2','B1','B2'];
const expected = {A0:100,A1:180,A2:220,B1:240,B2:260};
const headers = ['Уровень','Категория','Українська','Deutsch','English','Русский','Italiano','№','Тип','Обращение'];
const require = (value, message) => { if (!value) throw new Error(message); };
const normalize = text => text.normalize('NFC').toLowerCase().replace(/[.!?,;:…]/g,'').replace(/\s+/g,' ').trim();
const stageColors = {A0:'#E1F0E8',A1:'#E2EFDA',A2:'#FFF1CF',B1:'#DDEBF7',B2:'#EAE3F2'};
const data = [];
const seen = Array.from({length:5},()=>new Map());
const warnings = [];
for (const [index,m] of modules.entries()) {
  require(m.id === index+1, `Module order ${m.id}`);
  require(m.rows.length === 20, `Module ${m.id}: ${m.rows.length} rows`);
  require(levels.includes(m.level), `Level ${m.level}`);
  for (const id of m.review) require(id > 0 && id < m.id, `Invalid prerequisite ${m.id} -> ${id}`);
  for (const [ri,r] of m.rows.entries()) {
    require(r.length === 5 || r.length === 6, `Column count in ${m.id}.${ri+1}`);
    for (let language=0; language<5; language++) {
      const phrase=r[language];
      require(typeof phrase === 'string' && phrase.trim() === phrase && phrase.length > 0, 'Missing/padded phrase');
      require(!/[\uFFFD\u0000]/u.test(phrase), 'Invalid Unicode');
      require(!/^[=+@]/.test(phrase), 'Formula-like content');
      const key=normalize(phrase);
      require(!seen[language].has(key), `Duplicate language ${language}: ${phrase} (${seen[language].get(key)}, ${m.id}.${ri+1})`);
      seen[language].set(key,`${m.id}.${ri+1}`);
      if ([1,2,4].includes(language)) require(!/[А-Яа-яЁёІіЇїЄєҐґ]/u.test(phrase), `Cyrillic in translation ${m.id}.${ri+1}`);
    }
    require(!/[ыэъёЫЭЪЁ]/u.test(r[0]), `Russian letters in Ukrainian ${m.id}.${ri+1}`);
    const slots=r.slice(0,5).map(p=>(p.match(/\.\.\./g)||[]).length);
    require(new Set(slots).size === 1, `Slot counts ${m.id}.${ri+1}: ${slots}`);
    const type=m.id===49?'Идиома':slots[0]>0?'Модель':'Фраза';
    const register=r[5] ?? (/\b(Sie|Ihnen|Ihre?[nmsr]?)\b/.test(r[1])?'Вы':/\b(du|dir|dich|dein\w*)\b/i.test(r[1])?'ты':'нейтр.');
    data.push([m.level,`${String(m.id).padStart(2,'0')}. ${m.title}`,...r.slice(0,5),data.length+1,type,register]);
  }
}
require(modules.length===50 && data.length===1000,'Expected 50 modules and 1000 units');
for (const level of levels) require(data.filter(r=>r[0]===level).length===expected[level],`Count ${level}`);

const wb=Workbook.create();
const main=wb.worksheets.add('Core_Phrases_A0_B2');
const route=wb.worksheets.add('Маршрут');
const n=data.length+1;
main.getRange(`A1:J${n}`).values=[headers,...data];
main.showGridLines=false;
main.tabColor='#1F4E78';
main.getRange(`A1:J${n}`).format.font={name:'Arial',size:11,color:'#24313C'};
main.getRange(`A1:J${n}`).format.verticalAlignment='center';
main.getRange(`A2:J${n}`).format.wrapText=true;
main.getRange(`A1:A${n}`).format.columnWidth=10;
main.getRange(`B1:B${n}`).format.columnWidth=30;
main.getRange(`C1:G${n}`).format.columnWidth=40;
main.getRange(`H1:H${n}`).format.columnWidth=7;
main.getRange(`I1:I${n}`).format.columnWidth=12;
main.getRange(`J1:J${n}`).format.columnWidth=15;
main.getRange(`H2:H${n}`).setNumberFormat('0"  "');
main.getRange(`A2:A${n}`).format.horizontalAlignment='center';
main.getRange(`H2:H${n}`).format.horizontalAlignment='right';
main.getRange(`B2:B${n}`).format.font={name:'Arial',size:11,color:'#666666',italic:true};
const table=main.tables.add(`A1:J${n}`,true,'CorePhrases');
table.style='TableStyleLight9';
table.showFilterButton=true;
main.getRange('A1:J1').format={fill:'#1F4E78',font:{name:'Arial',size:12,bold:true,color:'#FFFFFF'},rowHeight:28,wrapText:true,horizontalAlignment:'center',verticalAlignment:'center'};
main.freezePanes.freezeRows(1);
main.freezePanes.freezeColumns(2);

function lineCount(text,limit) {
  let lines=1,length=0;
  for(const word of String(text).split(/\s+/)) {
    const size=word.length;
    if(length && length+1+size>limit){lines++;length=0;}
    if(size>limit){lines+=Math.floor(size/limit);length=size%limit;}
    else length+=(length?1:0)+size;
  }
  return lines;
}
for (let i=0;i<data.length;i++) {
  const row=i+2,r=data[i];
  const lines=Math.max(lineCount(r[1],26),...r.slice(2,7).map(p=>lineCount(p,35)));
  main.getRange(`A${row}:J${row}`).format.rowHeight=Math.max(30,lines*16+10);
  main.getRange(`A${row}`).format.fill=stageColors[r[0]];
  main.getRange(`A${row}`).format.font.bold=true;
  if(i%20===0) main.getRange(`A${row}:J${row}`).format.borders={top:{style:'thin',color:'#A8BACB'}};
}

route.showGridLines=false;
route.tabColor='#527B73';
route.getRange('A1:F88').format.font={name:'Arial',size:11,color:'#24313C'};
route.getRange('A1:F88').format.verticalAlignment='center';
const widths=[9,12,32,82,22,13];
for(let c=0;c<widths.length;c++) route.getRangeByIndexes(0,c,88,1).format.columnWidth=widths[c];
route.getRange('A1').values=[['Маршрут A0-B2']];
route.getRange('A1').format.font={name:'Arial',size:16,bold:true,color:'#1F4E78'};
route.getRange('A1:F1').format.rowHeight=30;
route.getRange('A3:C3').values=[['Уровень','Новых','Накопительно']];
route.getRange('A3:C3').format={fill:'#1F4E78',font:{name:'Arial',size:11,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',rowHeight:27};
for(let i=0;i<levels.length;i++) {
  const row=i+4,level=levels[i];
  route.getRange(`A${row}`).values=[[level]];
  route.getRange(`A${row}`).format.fill=stageColors[level];
  route.getRange(`B${row}`).formulas=[[`=COUNTIFS('Core_Phrases_A0_B2'!$A$2:$A$1001,A${row})`]];
  route.getRange(`C${row}`).formulas=[[`=SUM($B$4:B${row})`]];
}
route.getRange('A9').values=[['Всего']];
route.getRange('B9').formulas=[['=SUM(B4:B8)']];
route.getRange('A9:C9').format.font.bold=true;
route.getRange('B4:C9').setNumberFormat('#,##0');
route.getRange('C4:C8').setNumberFormat('#,##0"    "');
route.getRange('B4:C9').format.horizontalAlignment='right';
const notes=[
  'Одна строка: одна учебная единица в пяти языках. Переводы передают смысл, а не порядок слов.',
  'Фраза: готовая реплика. Модель: замените «...» своими данными. Идиома: устойчивое выражение со смысловым переводом.',
  'В моделях согласуйте вставки: артикль, падеж, число, предлог и форму глагола. Многоточия не являются пропущенными переводами.',
  'A0: вводный этап, примерно Pre-A1. Уровни остальных строк являются редакторским распределением общей коммуникативной задачи.',
  '«Вы»: вежливое обращение, обычно к одному человеку. «ты»: неформальное. «группа»: несколько слушателей. «нейтр.»: форма обращения несущественна.',
  'Формы говорящего с грамматическим родом обычно даны в мужском роде, как в примере. Женские формы адаптируются без новой единицы.',
  'В блоке 20 единиц. Начните с 5-8 за занятие, затем соберите короткий диалог и вернитесь к прежним блокам.',
  'Набор не гарантирует уровень B2 и не является официальным списком CEFR. Полная независимая проверка преподавателями пяти языков не проводилась.'
];
route.getRange('D3:D10').values=notes.map(t=>[t]);
route.getRange('D3:D10').format.wrapText=true;
route.getRange('D3:D10').format.font={name:'Arial',size:10,color:'#5A626A'};
for(let i=0;i<notes.length;i++) route.getRange(`A${i+3}:F${i+3}`).format.rowHeight=Math.max(32,lineCount(notes[i],82)*14+9);
route.getRange('A13:F13').values=[['Блок','Уровень','Категория','Коммуникативная задача','Повторить блоки','Единиц']];
const routeRows=modules.map(m=>[m.id,m.level,`${String(m.id).padStart(2,'0')}. ${m.title}`,m.goal,m.review.length?m.review.join(', '):'Начало',null]);
route.getRange('A14:F63').values=routeRows;
for(let i=0;i<modules.length;i++) {
  const row=i+14,m=modules[i];
  route.getRange(`F${row}`).formulas=[[`=COUNTIFS('Core_Phrases_A0_B2'!$B$2:$B$1001,C${row})`]];
  route.getRange(`A${row}:F${row}`).format.rowHeight=Math.max(38,lineCount(m.goal,78)*16+10,lineCount(m.title,28)*16+10);
  route.getRange(`B${row}`).format.fill=stageColors[m.level];
}
route.getRange('A14:F63').format.wrapText=true;
route.getRange('A14:B63').format.horizontalAlignment='center';
route.getRange('F14:F63').setNumberFormat('0');
route.getRange('F14:F63').format.horizontalAlignment='right';
const routeTable=route.tables.add('A13:F63',true,'LearningRoute');
routeTable.style='TableStyleLight9';
route.getRange('A13:F13').format={fill:'#1F4E78',font:{name:'Arial',size:11,bold:true,color:'#FFFFFF'},horizontalAlignment:'center',wrapText:true,rowHeight:32};

const sources=[
 ['Шаблон пользователя','Core_Phrases_A1_B2_Template.xlsx: порядок семи основных столбцов, пять языков, табличное оформление.'],
 ['Самостоятельная подборка','Фразы и переводы составлены для этого набора. Источники ниже служат ориентирами речевых задач, а не построчными источниками переводов.'],
 ['CEFR Companion Volume','https://www.coe.int/en/web/common-european-framework-reference-languages/cefr-companion-volume-and-its-language-versions'],
 ['Goethe: обсуждение','https://www.goethe.de/prj/mwd/tr/deu/tzs/muendlich/red.html'],
 ['Hueber: Momente','https://www.hueber.de/reihe/momente'],
 ['Momente: задания B1','https://www.hueber.de/media/36/Momente_B1-1_Unterrichtsplan_Lektion_5.pdf'],
 ['Дата подготовки','9 сентября 2026 года. Справочная разметка: версия 1.0.']
];
route.getRange('C67').values=[['Основа и ограничения']];
route.getRange('C67').format.font.bold=true;
route.getRange('C68:D74').values=sources;
route.getRange('C68:D74').format.wrapText=true;
route.getRange('C68:D74').format.font={name:'Arial',size:10,color:'#5A626A'};
for(let i=0;i<sources.length;i++) route.getRange(`C${68+i}:D${68+i}`).format.rowHeight=Math.max(34,lineCount(sources[i][1],84)*14+10);

main.getRange('A2').values=[['A1']];
require(route.getRange('B4').values[0][0]===99 && route.getRange('B5').values[0][0]===181,'Summary does not respond to a level change');
main.getRange('A2').values=[['A0']];
wb.recalculate();
console.log((await wb.inspect({kind:'table',range:'Маршрут!A3:C9',include:'values,formulas',tableMaxRows:7,tableMaxCols:3,maxChars:3000})).ndjson);
console.log((await wb.inspect({kind:'table',range:'Core_Phrases_A0_B2!A2:J3',include:'values',tableMaxRows:2,tableMaxCols:10,maxChars:1500})).ndjson);
console.log((await wb.inspect({kind:'table',range:'Core_Phrases_A0_B2!A992:J994',include:'values',tableMaxRows:3,tableMaxCols:10,maxChars:2800})).ndjson);
const errors=await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',options:{useRegex:true,maxResults:30},summary:'Formula error scan'});
console.log(errors.ndjson);
require(route.getRange('B9').values[0][0]===1000,'Summary did not recalculate');
for(let i=0;i<modules.length;i++) require(route.getRange(`F${i+14}`).values[0][0]===20,'Module formula incorrect');
const previews=process.argv.includes('--polish')?[
 ['Core_Phrases_A0_B2','A1:J4','phrases-start-final'],
 ['Core_Phrases_A0_B2','A879:J881','phrases-b2-final'],
 ['Маршрут','A1:F10','route-start-final']
]:[
 ['Core_Phrases_A0_B2','A1:G8','phrases-start'],
 ['Core_Phrases_A0_B2','A562:G566','phrases-middle'],
 ['Core_Phrases_A0_B2','A902:J906','phrases-b2'],
 ['Core_Phrases_A0_B2','A995:J1001','phrases-end'],
 ['Маршрут','A1:F18','route-start'],
 ['Маршрут','A60:F74','route-end']
];
for(const [sheetName,range,name] of previews){
  const preview=await wb.render({sheetName,range,scale:1,format:'png'});
  await fs.writeFile(path.join(supportDir,`${name}.png`),new Uint8Array(await preview.arrayBuffer()));
}
await fs.mkdir(outDir,{recursive:true});
const output=await SpreadsheetFile.exportXlsx(wb);
const outputPath=path.join(outDir,'Core_Phrases_A0_B2_1000_5_Languages.xlsx');
await output.save(outputPath);
const report={outputPath,modules:modules.length,units:data.length,translations:data.length*5,levels:expected,types:Object.fromEntries(['Фраза','Модель','Идиома'].map(type=>[type,data.filter(r=>r[8]===type).length])),uniqueByLanguage:seen.map(s=>s.size),renderedRanges:previews.map(p=>p.slice(0,2)),warnings};
await fs.writeFile(path.join(supportDir,'report.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report));
