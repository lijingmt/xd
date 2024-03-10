#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_DAEMON;
mapping(string:string) data=([]);
class Number{
	array(string) numbers=({"","十","百","千","万","十","百","千","亿","十","百","千","万","十","百","千"});
	array(string) digits=({"零","一","二","三","四","五","六","七","八","九"});
	string `[](int key){
		string out="";
		int is_negative;
		if(key<0){
			is_negative=1;
			key=-key;
		}
		int i=0;
		if(key==0){
			return digits[0];
		}
		int is_zero=1;
		while(key!=0){
			int n=key%10;
			if(n!=0&&is_zero){
				is_zero=0;
			}
			if(n!=0||i%4==0){
				if(sizeof(out)&&out[0..1]=="万"){
					//out=numbers[i]+out[2..];
					//将此处替换为out=numbers[i]+out;原来的算法将会把万位堆栈推出
					out=numbers[i]+out;
				}
				else{
					out=numbers[i]+out;
				}
			}
			if(n!=0){
				out=digits[n]+out;
			}
			else if(!is_zero){
				out="零"+out;
				is_zero=1;
			}
			key=key/10;
			i++;
		}
		if(out[0..3]=="一十"){
			out=out[2..];
		}
		if(is_negative)
			out="负"+out;
		return out;
	}
};
object number=Number();
string `[](mixed key){
	if(intp(key)){
		return number[key];
	}
	else if(stringp(key)){
		if(data[key]){
			return data[key];
		}
		else{
			return key;
		}
	}
}
string `[]=(string key, string val){
	return data[key]=val;
}

class Money{
	string `[](int key){
		string out="";
		array a=MUD_MONEYD->query_money_list();
		for(int i=0;i<sizeof(a);i++){
			object money=((object)(a[i]));
			if(key/money->value){
				out+=number[key/money->value]+money->unit+money->name_cn;
			}
			key=key%money->value;
		}
		if(out==""){
			out="零文钱";
		}
		return out;
	}
};
object money=Money();
class Daoheng{
	string `[](int key){
		string out="";
		if(key/1000){
			out+=number[key/1000]+"年";
		}
		if(key%1000/4){
			out+=number[key%1000/4]+"天";
		}
		if(key%4){
			out+=number[key%4*3]+"时辰";
		}
		if(out=="")
			return "没有修为";
		return out;
	}
};
object daoheng=Daoheng();
void main(int argc,array(string) argv){
	int n;
	sscanf(argv[1],"%d",n);
	write(this_object()[n]+"\n");
}
