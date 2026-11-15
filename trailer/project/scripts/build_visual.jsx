var ROOT='/tmp/mz_trailer/';
var W=1920,H=1080,D=29.7,FPS=30;
var cream=[244/255,235/255,217/255], muted=[139/255,155/255,180/255], amber=[245/255,166/255,35/255], cyan=[56/255,189/255,248/255], dark=[8/255,12/255,22/255];
var main=app.project.items.addComp('Main',W,H,1,D,FPS);
main.bgColor=dark;
function prop(l,n){return l.property('ADBE Transform Group').property('ADBE '+n);}
function span(l,a,b){l.inPoint=a;l.outPoint=b;return l;}
function pos(l,x,y){prop(l,'Position').setValue([x,y,0]);}
function scale(l,x,y){prop(l,'Scale').setValue([x,y===undefined?x:y,100]);}
function alpha(l,v){prop(l,'Opacity').setValue(v);}
function key(l,n,t,v){prop(l,n).setValueAtTime(t,v);}
function solid(c,n,col,x,y,w,h,a,b){var l=c.layers.addSolid(col,n,w,h,1,D);pos(l,x+w/2,y+h/2);return span(l,a,b);}
function text(c,s,x,y,size,col,a,b,center,mono){
 var l=c.layers.addText(s);l.name=s.replace(/\n/g,' ').slice(0,90);
 var p=l.property('ADBE Text Properties').property('ADBE Text Document'),d=p.value;
 d.font=mono?'Space Mono':'Exo 2';d.fontSize=size;d.fillColor=col;d.justification=center?ParagraphJustification.CENTER_JUSTIFY:ParagraphJustification.LEFT_JUSTIFY;d.leading=size*1.22;
 p.setValue(d);pos(l,x,y);return span(l,a,b);
}
var footage={};
function imp(file){if(!footage[file])footage[file]=app.project.importFile(new ImportOptions(new File(ROOT+'assets/'+file)));return footage[file];}
function image(c,file,x,y,pct,a,b){var l=c.layers.add(imp(file));pos(l,x,y);scale(l,pct);span(l,a,b);return l;}
function grow(l,a,b,s1,s2){key(l,'Scale',a,[s1,s1,100]);key(l,'Scale',b,[s2,s2,100]);}
function reveal(l,a,s1,s2){for(var k=0;k<=6;k++){var q=k/6;var v=s2+(s1-s2)*Math.pow(1-q,3);key(l,'Scale',a+k/FPS,[v,v,100]);}}
function fade(l,a,b,v1,v2){key(l,'Opacity',a,v1);key(l,'Opacity',b,v2);}
function tricolor(c,a,b){solid(c,'Terracotta flight stripe',[.784,.243,.169],80,66,56,6,a,b);solid(c,'Amber flight stripe',amber,140,66,56,6,a,b);solid(c,'Cyan flight stripe',cyan,200,66,56,6,a,b);}
function footer(a,b){text(main,'TEAM SKAAR  /  MISSION DESIGN',80,922,17,muted,a,b,false,false);text(main,'MARGIN ZERO · ORBITAL DEBT',1630,922,17,muted,a,b,true,false);}
var bg=image(main,'space.png',960,540,100,0,D);grow(bg,0,D,100,103);
tricolor(main,0,D);
text(main,'NASA SPACE APPS CHALLENGE 2026 · THE NEXT FRONTIER',294,83,22,muted,0,3,false,false);
text(main,'ANÁHUAC MAYAB  /  MÉRIDA, MÉXICO',80,160,19,amber,0,3,false,false);
var team=text(main,'Team Skaar',126,460,155,cream,0,3,false,false);reveal(team,0,96,100);
text(main,'Anáhuac Mayab · Mérida, Yucatán, México',135,552,35,muted,0,3,false,false);
var emblem=image(main,'logo_orbita.png',1470,485,46,0,3);grow(emblem,0,3,45,47);
solid(main,'Opening rule',amber,138,615,112,4,0,3);
text(main,'SPACE MISSION DESIGN GAME',138,674,23,cream,0,3,false,false);
footer(0,7.866666667);

text(main,'OUR CHALLENGE:',136,235,26,amber,3,7.866666667,false,false);
text(main,'Space Mission\nDesign Game',130,360,100,cream,3,7.866666667,false,false);
text(main,'Students rarely see how a',138,645,38,muted,3,7.866666667,false,false);
text(main,'real space mission',138,702,48,amber,3.5,7.866666667,false,false);
text(main,'is designed.',138,765,38,cream,3.9,7.866666667,false,false);
var challengeMark=image(main,'logo_orbita.png',1500,510,37,3,7.866666667);alpha(challengeMark,30);grow(challengeMark,3,7.85,37,40);

// Title emblem and wordmark animate independently to keep the subtitle stable.
var mark=image(main,'logo_orbita.png',1450,465,52,8,12);reveal(mark,8,59.28,52);
text(main,'MISSION BRIEF  /  ZERO ENGINEERING MARGIN',136,230,22,amber,8,12,false,false);
var title=text(main,'Margin Zero',128,462,136,cream,8,12,false,false);reveal(title,8,114,100);
text(main,'ORBITAL DEBT',138,555,48,muted,8,12,false,false);
text(main,'Space mission design with',138,680,37,cream,8,12,false,false);
text(main,'zero margin',138,738,45,amber,8,12,false,false);
text(main,'for error.',398,738,45,cream,8,12,false,false);
footer(8,12);

var steps=['CONTRACT','BUILD','LAUNCH','FLY','LAND','DEBRIEF'];
var copy=['Payout, deadline, danger.','Cheap parts, hidden flaws.','Hit T-0. Survive Max-Q.','Solar flares hit. Choose fast.','Stay in the entry corridor.','What went wrong, and why.'];
var starts=[12,13.5,15,17,21,23],ends=[13.5,15,17,21,23,25];
text(main,'HOW IT PLAYS',80,159,27,cream,12,25,false,false);
solid(main,'Navigation rule',[.16,.21,.29],80,194,300,1,12,25);
for(var i=0;i<6;i++){
 var num=('0'+(i+1)).slice(-2),yy=286+i*84;
 text(main,num,84,yy,19,muted,12,25,false,false);
 text(main,steps[i],135,yy,28,muted,12,25,false,false);
 text(main,steps[i],135,yy,28,cream,starts[i],ends[i],false,false);
 solid(main,'Active step '+num,amber,58,yy-29,4,38,starts[i],ends[i]);
 text(main,num+' / '+steps[i],462,90,23,amber,starts[i],ends[i],false,false);
 text(main,copy[i],1100,90,26,cream,starts[i],ends[i],false,false);
}
text(main,'PLAY. FAIL.\nUNDERSTAND.',80,870,24,muted,12,25,false,false);
var shots=[['1_hangar.png',12,13.5,0],['2_assembly.png',13.5,15,1],['3_launch.png',15,17,2],['4_space.png',17,18,3],['7_carta.png',18,21,3],['5_descent_entrada.png',21,22,4],['5_descent_vuelo.png',22,23,4],['6_debrief.png',23,25,5]];
for(var j=0;j<shots.length;j++){
 var row=shots[j],a=row[1],b=row[2],idx=row[3];
 var pc=app.project.items.addComp('Shot '+j+' '+steps[idx],1400,788,1,D,FPS);pc.bgColor=dark;
 var pic=image(pc,'shots/'+row[0],700,394,72.9167,0,D);
 // Keep native game UI visible; only modest overscan for cinematic movement.
 var z0=72.9167,z1=76.6;
 if(idx==1){z0=74;z1=74;key(pic,'Position',a,[700,410,0]);key(pic,'Position',b,[700,380,0]);}
 if(idx==3 && a==18){z0=90;z1=94;pos(pic,730,430);}
 if(idx==5){z0=100;z1=105;pos(pic,700,394);}
 if(idx==4){z0=74;z1=79;}
 grow(pic,a,b,z0,z1);
 if(idx==2 || (idx==4 && a==22)){
  for(var f=Math.round(a*FPS);f<Math.round(b*FPS);f++){
   var t=f/FPS,shake=(idx==2 && t<15.2)?0:3;
   key(pic,'Position',t,[700+Math.sin(f*2.41)*shake,394+Math.cos(f*1.73)*shake,0]);
  }
 }
 image(pc,'vignette.png',700,394,72.9167,0,D);
 var frame=main.layers.add(pc);pos(frame,1160,532);span(frame,a,b);
}
// The badge is separate from the solar card and does not obstruct game choices.
solid(main,'NASA badge background',[.06,.12,.17],1120,106,740,44,17,21);
text(main,'MODELED ON NASA & JPL OPEN DATA',1490,137,24,cyan,17,21,true,false);
var flash=solid(main,'Solar warning amber',amber,460,138,1400,788,18,18.3);fade(flash,18,18.3,17,0);
solid(main,'Screen frame top',[.18,.25,.32],460,137,1400,1,12,25);
solid(main,'Screen frame bottom',[.18,.25,.32],460,926,1400,1,12,25);

// Closing: all required sources remain readable until the final fade.
image(main,'logo_orbita.png',960,268,25,25,D);
var closeTitle=text(main,'Margin Zero',960,488,107,cream,25,D,true,false);reveal(closeTitle,25,104,100);
text(main,'Training the next generation of mission designers.',960,584,43,cream,25,D,true,false);
text(main,'BUILT ON NASA & JPL OPEN DATA',960,694,23,cyan,25,D,true,false);
var sources=['NASA Planetary Fact Sheet','JPL Small-Body Database','NASA DONKI','NASA Deep Space Network'];
var xs=[320,755,1145,1570];
for(var n=0;n<4;n++){
 var ts=25.5+Math.round(n*7.5)/30;
 var sl=text(main,sources[n],xs[n],766,25,muted,ts,D,true,false);fade(sl,ts,ts+.15,0,100);
}
text(main,'Team Skaar · Anáhuac Mayab, Mérida, Yucatán, México',960,861,28,muted,25,D,true,false);

// Exact English subtitles, each with an exclusive end, no overlap at the title cut.
var subs=[
 [0.15,2.85,'We are Team Skaar, from Mérida, Mexico.'],
 [3.10,7.80,'Our challenge: Space Mission Design Game.\nStudents rarely see how a real mission is designed.'],
 [8.10,11.85,'So we built Margin Zero: mission design with zero margin for error.'],
 [12.10,14.85,'Pick a contract. Build a rocket on a tight budget.'],
 [15.08,16.90,'Launch, and fly it yourself.'],
 [17.10,20.85,'Space fights back, modeled on NASA and JPL open data.'],
 [23.08,24.90,'Every flight ends with a debrief of what went wrong.'],
 [25.10,29.10,'Training the next generation of mission designers.']
];
for(var v=0;v<subs.length;v++){
 var st=Math.ceil(subs[v][0]*FPS)/FPS,en=Math.floor(subs[v][1]*FPS)/FPS;
 var box=solid(main,'Caption backing '+(v+1),dark,230,968,1460,94,st,en);alpha(box,94);
 text(main,subs[v][2],960,subs[v][2].indexOf('\n')>=0?998:1024,32,cream,st,en,true,false);
}
solid(main,'Pre-drop black — frames 236–239',[0,0,0],0,0,W,H,236/30,8);
var endfade=solid(main,'Final fade',[0,0,0],0,0,W,H,29.3,D);fade(endfade,29.3,29.7,0,100);
main.openInViewer();
app.project.save(new File(ROOT+'margin_zero_trailer.ecproj'));
writeLn('Main built: 1920x1080, 30fps, 891 frames.');
