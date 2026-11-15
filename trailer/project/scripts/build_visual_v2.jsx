var ROOT='/tmp/mz_trailer/',W=1920,H=1080,D=29.7,FPS=30;
var ink=[244/255,235/255,217/255],amber=[240/255,156/255,20/255],cyan=[56/255,189/255,248/255],dim=[.65,.72,.78],black=[3/255,6/255,9/255];
var main=app.project.items.addComp('Main',W,H,1,D,FPS);
main.bgColor=black;main.motionBlur=true;main.shutterAngle=240;main.shutterPhase=-120;main.motionBlurSamplesPerFrame=6;
var files={};
function P(l,n){return l.property('ADBE Transform Group').property('ADBE '+n);}
function xy(l,x,y){P(l,'Position').setValue([x,y,0]);}
function sc(l,s){P(l,'Scale').setValue([s,s,100]);}
function op(l,v){P(l,'Opacity').setValue(v);}
function K(l,n,t,v){P(l,n).setValueAtTime(t,v);}
function span(l,a,b){l.inPoint=a;l.outPoint=b;return l;}
function mb(l){l.motionBlur=true;return l;}
function footage(path){if(!files[path])files[path]=app.project.importFile(new ImportOptions(new File(ROOT+'assets/'+path)));return files[path];}
function img(c,path,x,y,s,a,b){var l=c.layers.add(footage(path));xy(l,x,y);sc(l,s);span(l,a,b);return l;}
function solid(c,name,col,x,y,w,h,a,b){var l=c.layers.addSolid(col,name,w,h,1,D);xy(l,x+w/2,y+h/2);span(l,a,b);return l;}
function txt(c,s,x,y,size,color,a,b,align,font){
 var l=c.layers.addText(s);l.name=s.replace(/\n/g,' ').slice(0,90);var p=l.property('ADBE Text Properties').property('ADBE Text Document'),d=p.value;
 d.font=font||'Exo 2';d.fontSize=size;d.fillColor=color;d.justification=align=='center'?ParagraphJustification.CENTER_JUSTIFY:(align=='right'?ParagraphJustification.RIGHT_JUSTIFY:ParagraphJustification.LEFT_JUSTIFY);d.leading=size*1.13;
 p.setValue(d);xy(l,x,y);return span(l,a,b);
}
function ease(l,prop,a,b,start,end){
 for(var i=0;i<=8;i++){
  var t=i/8,q=1-Math.pow(1-t,3),v;
  if(typeof start=='number')v=start+(end-start)*q;
  else {v=[];for(var j=0;j<start.length;j++)v.push(start[j]+(end[j]-start[j])*q);}
  K(l,prop,a+(b-a)*t,v);
 }
}
function entrance(l,a,x,y,dx,dy,duration){mb(l);ease(l,'Position',a,a+duration,[x+dx,y+dy,0],[x,y,0]);ease(l,'Opacity',a,a+.12,0,100);}
function zoom(l,a,b,s0,s1){K(l,'Scale',a,[s0,s0,100]);K(l,'Scale',b,[s1,s1,100]);mb(l);}
function reveal(l,a,x,y,s){mb(l);ease(l,'Scale',a,a+.28,[s*1.32,s*1.32,100],[s,s,100]);ease(l,'Position',a,a+.28,[x,y+70,0],[x,y,0]);}
function grade(a,b,level){var l=img(main,'title_shade.png',960,540,100,a,b);op(l,level||100);}
function stripes(a,b){var x=102,y=100;solid(main,'Flight stripe red',[.784,.243,.169],x,y,42,5,a,b);solid(main,'Flight stripe amber',amber,x+47,y,42,5,a,b);solid(main,'Flight stripe cyan',cyan,x+94,y,42,5,a,b);}

// Real repository space texture and planet, animated as separate depth planes.
var base=img(main,'repo/space_bg_deep_void.png',960,540,420,0,D);zoom(base,0,D,420,445);
var neb=img(main,'repo/space_bg_nebula_teal.png',1450,530,310,0,8);op(neb,40);zoom(neb,0,8,310,345);K(neb,'Position',0,[1450,530,0]);K(neb,'Position',8,[1310,500,0]);
var earth=img(main,'repo/planet_earth.png',1540,890,750,0,7.866666667);zoom(earth,0,8,750,850);K(earth,'Position',0,[1540,890,0]);K(earth,'Position',8,[1600,970,0]);
grade(0,8,88);stripes(0,3);
txt(main,'NASA Space Apps Challenge 2026 · The Next Frontier',102,166,26,ink,0,3,'left','Exo 2');
var team=txt(main,'Team Skaar',100,525,172,ink,0,3,'left','Pixelta');entrance(team,0,100,525,-150,0,.50);
var venue=txt(main,'Anáhuac Mayab',108,624,48,ink,.20,3,'left','Exo 2');entrance(venue,.20,108,624,0,45,.36);
txt(main,'Mérida, Yucatán, México',108,684,34,dim,.35,3,'left','Exo 2');

var our=txt(main,'Our challenge:',104,218,38,amber,3,7.866666667,'left','Exo 2');entrance(our,3,104,218,-70,0,.3);
var challenge=txt(main,'Space Mission\nDesign Game',100,377,118,ink,3,7.866666667,'left','Exo 2 SemiBold');entrance(challenge,3,100,377,0,130,.44);
var line1=txt(main,'Students rarely see how a',108,727,42,ink,3.35,7.866666667,'left','Exo 2');entrance(line1,3.35,108,727,0,28,.32);
txt(main,'real space mission is designed.',108,786,44,amber,3.6,7.866666667,'left','Exo 2');

// Hero title: native motion blur catches the fast scale/position arrival.
var titleSpace=img(main,'repo/space_bg_nebula_crimson.png',960,540,380,8,12);zoom(titleSpace,8,12,410,370);op(titleSpace,50);grade(8,12,100);
var mark=img(main,'logo_orbita.png',960,274,24,8,12);reveal(mark,8,960,274,24);
var title=txt(main,'Margin Zero',960,562,174,ink,8,12,'center','Pixelta');reveal(title,8,960,562,100);
var debt=txt(main,'Orbital Debt',960,655,52,amber,8.08,12,'center','Exo 2 SemiBold');entrance(debt,8.08,960,655,0,85,.32);
txt(main,'Space mission design with zero margin for error.',960,758,40,ink,8.20,12,'center','Exo 2');
var flare=solid(main,'Title exposure flash',ink,0,0,W,H,8,8.10);K(flare,'Opacity',8,20);K(flare,'Opacity',8.10,0);

var shots=[
 ['contract',12,13.5,.25,0,105,111,0,0],
 ['build',13.5,15,.30,1,104,108,0,-12],
 ['launch',15,17,.35,2,102,111,-35,5],
 ['space',17,18,.25,3,108,103,0,0],
 ['solar',18,21,.25,3,123,133,80,15],
 ['entry',21,22,.10,4,107,119,0,0],
 ['reentry',22,23,.30,4,111,124,0,0],
 ['debrief',23,25,.25,5,155,163,0,0]
];
var labels=['Contract','Build','Launch','Fly','Land','Debrief'];
var copy=['Payout, deadline, danger.','Cheap parts, hidden flaws.','Hit T-0. Survive Max-Q.','Solar flares hit. Choose fast.','Stay in the entry corridor.','What went wrong, and why.'];
var starts=[12,13.5,15,17,21,23],ends=[13.5,15,17,21,23,25];
for(var j=0;j<shots.length;j++){
 var q=shots[j],a=q[1],b=q[2];
 var l=img(main,'clips/'+q[0]+'.mp4',960+q[7],540+q[8],q[5],a,b);l.startTime=a-q[3];span(l,a,b);mb(l);
 zoom(l,a,b,q[5],q[6]);
 var x=960+q[7],y=540+q[8];
 // Brief directional edits, followed by purposeful camera travel.
 if(q[0]=='build')ease(l,'Position',a,a+.22,[x,y+135,0],[x,y,0]);
 else if(q[0]=='solar')ease(l,'Position',a,a+.22,[x+120,y,0],[x,y,0]);
 else ease(l,'Position',a,a+.20,[x-60,y+20,0],[x,y,0]);
 if(q[0]=='launch' || q[0]=='reentry'){
  for(var f=Math.round((a+.22)*30);f<=Math.round(b*30);f++){
   var amt=q[0]=='launch'?3.5:5;
   K(l,'Position',f/30,[x+Math.sin(f*2.2)*amt,y+Math.cos(f*1.8)*amt,0]);
  }
 }
}
img(main,'cinema_shade.png',960,540,100,12,25);
var cardBg=solid(main,'Step HUD backing',black,76,682,496,244,12,25);op(cardBg,88);
var cardAccent=solid(main,'Step HUD amber bar',amber,76,682,5,244,12,25);
txt(main,'HOW IT PLAYS',104,724,20,cyan,12,25,'left','Exo 2 SemiBold');
for(var i=0;i<6;i++){
 var a=starts[i],b=ends[i],num=('0'+(i+1)).slice(-2);
 var number=txt(main,num,258,724,22,amber,a,b,'left','Space Mono');entrance(number,a,258,724,0,18,.22);
 var name=txt(main,labels[i],103,822,80,ink,a,b,'left','Pixelta');entrance(name,a,103,822,-120,0,.28);
 var desc=txt(main,copy[i],106,884,31,ink,a+.06,b,'left','Exo 2');entrance(desc,a+.06,106,884,0,28,.28);
}
var badgeBg=solid(main,'NASA badge backing',black,670,52,580,54,17,21);op(badgeBg,90);
var badgeRule=solid(main,'NASA badge cyan rule',cyan,670,52,580,3,17,21);
var badge=txt(main,'MODELED ON NASA & JPL OPEN DATA',960,88,24,cyan,17,21,'center','Exo 2 SemiBold');entrance(badge,17,960,88,0,-24,.28);
var warn=solid(main,'Solar amber exposure',amber,0,0,W,H,18,18.22);K(warn,'Opacity',18,16);K(warn,'Opacity',18.22,0);

// Final lockup uses the same in-game face as the title screen.
var finish=img(main,'repo/space_bg_nebula_teal.png',960,540,380,25,D);op(finish,30);zoom(finish,25,D,380,397);grade(25,D,100);
var closeLogo=img(main,'logo_orbita.png',960,215,21,25,D);reveal(closeLogo,25,960,215,21);
var close=txt(main,'Margin Zero',960,460,144,ink,25,D,'center','Pixelta');entrance(close,25,960,460,0,85,.35);
var tagline=txt(main,'Training the next generation\nof mission designers.',960,566,45,ink,25.12,D,'center','Exo 2');entrance(tagline,25.12,960,566,0,55,.4);
txt(main,'Built on NASA & JPL open data',960,716,27,cyan,25.35,D,'center','Exo 2');
var sources=['NASA Planetary Fact Sheet','JPL Small-Body Database','NASA DONKI','NASA Deep Space Network'];
for(var i=0;i<4;i++){
 var x=i%2==0?590:1330,y=i<2?778:830,a=25.50+Math.round(i*7.5)/30;
 var s=txt(main,sources[i],x,y,29,ink,a,D,'center','Exo 2');entrance(s,a,x,y,0,20,.25);
}
txt(main,'Team Skaar · Anáhuac Mayab, Mérida, Yucatán, México',960,909,25,dim,25.6,D,'center','Exo 2');
var subs=[
 [.15,2.85,'We are Team Skaar, from Mérida, Mexico.'],
 [3.10,7.80,'Our challenge: Space Mission Design Game.\nStudents rarely see how a real mission is designed.'],
 [8.10,11.85,'So we built Margin Zero: mission design with zero margin for error.'],
 [12.10,14.85,'Pick a contract. Build a rocket on a tight budget.'],
 [15.08,16.90,'Launch, and fly it yourself.'],
 [17.10,20.85,'Space fights back, modeled on NASA and JPL open data.'],
 [23.08,24.90,'Every flight ends with a debrief of what went wrong.'],
 [25.10,29.10,'Training the next generation of mission designers.']
];
for(var i=0;i<subs.length;i++){
 var a=Math.ceil(subs[i][0]*30)/30,b=Math.floor(subs[i][1]*30)/30,s=subs[i][2];
 var shadow=solid(main,'Subtitle dark backing '+i,black,215,967,1490,90,a,b);op(shadow,82);
 txt(main,s,960,s.indexOf('\n')>=0?997:1021,32,ink,a,b,'center','Exo 2');
}
solid(main,'Pre-drop black, frames 236–239',[0,0,0],0,0,W,H,236/30,8);
var fade=solid(main,'Clean ending',[0,0,0],0,0,W,H,29.3,D);K(fade,'Opacity',29.3,0);K(fade,'Opacity',D,100);
main.openInViewer();app.project.save(new File(ROOT+'margin_zero_trailer_v2.ecproj'));
writeLn('v2: Pixelta + Exo 2 + moving gameplay + native 240-degree shutter motion blur');
