#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_DAEMON;
mapping(string:string) data=([]);
void emote(string msg,object self,object target,void|int no_others){
	if(self==0||target==0){
		return;
	}
	array(string) msgs=expand(msg);
	tell_object(self,filter(msgs[0],self,target,self));
	tell_object(target,filter(msgs[1],self,target,target));
	object env=environment(self);
	if(!no_others&&env&&env->is("room"))
		env->addRemainMSG(filter(msgs[2],self,target),(<self->name,target->name>));
}
array(string) expand(string msg){
	return ({replace(msg,(["$N":"$P","$p":"$n","$L":"$Q","$Q":"$L"])),replace(msg,([])),replace(msg,(["$p":"$n","$L":"$Q"]))});
}
string filter(string msg,object emoter,object target,void|object looker){
	if(emoter==0||target==0){
		return "";
	}
	string P=emoter->query_pronoun(looker);
	string p=target->query_pronoun(looker);
	string R="朋友";
	string r="朋友";
	string U="匹夫";
	string u="匹夫";
	string S="在下";
	string s="本人";
	string W="";
	string w="";
	mapping emoter_equip = emoter->query_equip();
	mapping target_equip = target->query_equip();
	if(emoter_equip&&emoter_equip["weapon"]){
		W = (emoter_equip["weapon"])->query_name_cn();
	}
	if(target_equip&&target_equip["weapon"]){
		w = (target_equip["weapon"])->query_name_cn();
	}
	array(string) parts=target->query_parts();
	string a="身体";
	if(parts&&sizeof(parts)){
		a=parts[random(sizeof(parts))];
	}
	array(string) Parts=emoter->query_parts();
	string A="身体";
	if(Parts&&sizeof(Parts)){
		A=Parts[random(sizeof(Parts))];
	}
	werror("\n====== msg["+msg+"]======\n");
	return replace(msg,(["$N":emoter->query_name_cn(),
				"$n":target->query_name_cn(),
				"$P":P,
				"$p":p,
				"$A":A,
				"$a":a,
				"$R":R,
				"$r":r,
				"$U":U,
				"$u":u,
				"$S":S,
				"$s":s,
				"$Q":"去",
				"$L":"来",
				"$W":W,
				"$w":w
				]));
}
