#include <globals.h>
#include <gamelib.h>
inherit LOW_FILTER;
inherit Crypto.DES;
//inherit Crypto.Cipher;
//inherit Nettle.DES_Info;
//inherit Nettle.CipherState;
//inherit Nettle.CipherInfo;
array(string) input;
string out;
int in_form;
void create()
{
	::create();
	input=({});
	out="";
}
string setup(string _url)
{
	url=_url;
	/*
	out+="ContentType=text/html\nCharset=ISO-8859-1\n\n";
	out+="<html  xmlns=\"http://www.w3.org/1999/xhtml\">";
	out+= "<head>";
	out+= "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />";
	out+= "<title>xdtest</title>";
	out+= "</head>";
	out+= "<body>";
	*/
	out+="\n";
	out+="<!DOCTYPE html>\n";
	out+="<html>\n";
	out+= "<head>\n";
	//out+= "<%@ page language=\"java\" contentType=\"text/html;charset=UTF-8\"%>";
	out+= "<meta charset=\"UTF-8\">\n"; 
	out+= "<meta name=\"viewport\" content=\"maximum-scale=1.0,minimum-scale=1.0,user-scalable=0,width=device-width,initial-scale=1.0\"/>\n"; 
	out+= "<title>《仙道》（" + get_game_area() + "区） 《游戏泥巴》WAP泥巴 文字游戏 WAP游戏 怀旧网游 WAP文字游戏 手机游戏 手机复古游戏 手机武侠游戏 苹果游戏 安卓游戏</title>\n";
	out+= "<link rel=\"icon\" type=\"image/x-icon\" href=\"images/favicon.ico\">";
	out+= "<link rel=\"stylesheet\" href=\"includes/bootstrap-4.6.2-dist/css/bootstrap.min.css?v=3\"/>\n";
	out+= "<link href=\"includes/intro.css\" rel=\"stylesheet\" type=\"text/css\"/>\n";
	out+= "</head>\n";
	out+= "<body>\n"; 
	out+= "<div>\n"; 
	
	return "";
}
string get_game_area(){
	return TOPTEN->get_game_area();
}
string net_dead()
{
	//werror("\n555555555555555555555 html5.pike net_dead call 555555555555555555555555555555\n");
	//out+="</html>";
	out+="</body><script src=\"includes/translate.js\"></script><script>translate.language.setLocal('chinese_simplified'); translate.service.use('client.edge'); translate.setAutoDiscriminateLocalLanguage();translate.execute();</script></html>";
	//out+="</body></html>";
	input=({});
	string o=out;
	out="";
	return o;
}
string process_input(string s)
{
	mixed err;
	err=catch{
		//s=utf8_to_string(s);//Locale.Charset.encoder("euc_cn")->feed(s)->drain();
		//s=Locale.Charset.encoder("euc_cn")->feed(s)->drain();
		s = decode(s);
	};
	if(err){
		s="charerror "+s;
	}
	if(sizeof(s)&&s[0]>='0'&&s[0]<='9'){
		int n;
		string tail="";
		sscanf(s,"%d %s",n,tail);
		if(this_player()["hidden"]){
			if(n<sizeof(this_player()->hidden))
				s=this_player()->hidden[n]+tail;
			else 
				s="look";
		}
	}
	return s;
}
private string decode(string s)
{
	string out="";
	for(int i=0;i<sizeof(s);i++){
		if(s[i]=='%'){
			if(i<sizeof(s)-1){
				if(s[i+1]=='%'){
					out+='%';
					i++;
				}
				else if(s[i+1]>='0'&&s[i+1]<='9'){
					int n;
					sscanf(s[i+1..],"%d",n);
					out+=sprintf("%c",n);
					while(i<sizeof(s)-1&&s[i+1]>='0'&&s[i+1]<='9'){
						i++;
					}
				}
				else{
					out+="%";
				}
			}
		}
		else if(s[i]>=0&&s[i]<128){
			out+=replace(s[i..i],(["&":"&amp;","\n":"<br/>"]));
		}
		else{
			out+=s[i..i+1];
			i++;
		}
	}
	return out;
	//string t=Locale.Charset.decoder("euc_cn")->feed(s)->drain();
	//return t;
}
string get_right_href_css(string link_name)
{
	string hrefcss="btn btn-outline-info btn-sm";
	string hrefcss_warning="btn btn-outline-warning btn-sm";
	string hrefcss_blue="btn btn-outline-primary btn-sm";
	string hrefcss_green="btn btn-outline-success btn-sm";
	string hrefcss_gray="btn btn-outline-secondary btn-sm";
	string hrefcss_orange="btn btn-outline-orange btn-sm";
	string hrefcss_darkorange="btn btn-outline-darkorange btn-sm";
	string hrefcss_purple="btn btn-outline-purple btn-sm";
	string hrefcss_green2="btn btn-outline-green btn-sm";
	string hrefcss_tian="btn btn-outline-tian btn-sm";
	string hrefcss_di="btn btn-outline-di btn-sm";
	string hrefcss_xuan="btn btn-outline-xuan btn-sm";
	string hrefcss_huang="btn btn-outline-huang btn-sm";
	mixed err= catch{
		mapping(string:string) primary_key_map=([]);
		primary_key_map["9*"]=hrefcss_huang;
		primary_key_map["8*"]=hrefcss_xuan;
		primary_key_map["7*"]=hrefcss_tian;
		primary_key_map["6*"]=hrefcss_di;
		primary_key_map["5*"]=hrefcss_green2;
		primary_key_map["4*"]=hrefcss_orange;
		primary_key_map["3*"]=hrefcss_purple;
		primary_key_map["2*"]=hrefcss_blue;
		primary_key_map["1*"]=hrefcss_gray;
		
		
		primary_key_map["东→"]=hrefcss_green;
		primary_key_map["西←"]=hrefcss_green;
		primary_key_map["南↓"]=hrefcss_green;
		primary_key_map["北↑"]=hrefcss_green;
		primary_key_map["快速攻击"]=hrefcss_warning;
		primary_key_map["驿站"]=hrefcss_warning;
		primary_key_map["商城"]=hrefcss_warning;
		primary_key_map["锻造"]=hrefcss_warning;
		primary_key_map["黑市"]=hrefcss_orange;
		primary_key_map["【强化】"]=hrefcss_orange;
		primary_key_map["合成"]=hrefcss_orange;
		primary_key_map["宝商"]=hrefcss_orange;
		primary_key_map["精炼"]=hrefcss_orange;
		primary_key_map["隐秘幻境"]=hrefcss_warning;
		primary_key_map["任务"]=hrefcss_green;
		primary_key_map["尸体"]=hrefcss_gray;
		primary_key_map["武功"]=hrefcss_green;
		primary_key_map["状态"]=hrefcss_green;
		primary_key_map["吃药"]=hrefcss_purple;
		primary_key_map["白银"]=hrefcss_warning;
		primary_key_map["闪亮的石块(盲盒)"]=hrefcss_green;
		primary_key_map["魔皮荷包(盲盒)"]=hrefcss_green2;
		primary_key_map["魔精袋子(盲盒"]=hrefcss_darkorange;
		primary_key_map["魔铁宝箱(盲盒)"]=hrefcss_orange;
		primary_key_map["魔金宝箱(盲盒)"]=hrefcss_purple;
		primary_key_map["幸运宝石"]=hrefcss_purple;
		primary_key_map["「壹」"]=hrefcss_green;
		primary_key_map["「捌」"]=hrefcss_darkorange;
		primary_key_map["「陆」"]=hrefcss_green2;
		primary_key_map["「伍」"]=hrefcss_green2;
		primary_key_map["「贰」"]=hrefcss_green;
		primary_key_map["「肆」"]=hrefcss_green2;
		primary_key_map["「贰」"]=hrefcss_green;
		primary_key_map["「柒」"]=hrefcss_darkorange;
		primary_key_map["「玖」"]=hrefcss_darkorange;
		primary_key_map["「拾」"]=hrefcss_darkorange;
		primary_key_map["「十贰」"]=hrefcss_orange;
		primary_key_map["「拾壹」"]=hrefcss_orange;
		primary_key_map["「十叁」"]=hrefcss_purple;
		primary_key_map["「地-"]=hrefcss_di;
		primary_key_map["「天-"]=hrefcss_tian;
		primary_key_map["「黄-"]=hrefcss_huang;
		primary_key_map["「玄-"]=hrefcss_xuan;

		primary_key_map["【优良】"]=hrefcss_blue;
		primary_key_map["【精制】"]=hrefcss_darkorange;
		primary_key_map["【神炼】"]=hrefcss_purple;
		primary_key_map["【天降】"]=hrefcss_green2;
		primary_key_map["【幻化】"]=hrefcss_orange;
		primary_key_map["【空觉】"]=hrefcss_di;
		primary_key_map["【破空】"]=hrefcss_tian;
		primary_key_map["【寂灭】"]=hrefcss_huang;
		
		primary_key_map["【玉】碎玉"]=hrefcss_blue;
		primary_key_map["【玉】仙缘玉"]=hrefcss_darkorange;
		primary_key_map["【玉】玲珑玉"]=hrefcss_purple;
		primary_key_map["【玉】碧玺玉"]=hrefcss_green2;
		primary_key_map["【玉】玄天宝玉"]=hrefcss_xuan;
		primary_key_map["神秘商店"]=hrefcss_darkorange;
		
		//vip level shows different color
		
		mapping(string:int) grade_mapping=TOPTEN->get_grade_mapping();
		foreach(grade_mapping;string index;int n){
			//werror("=======index:"+index+"\n");
			//werror("=======n:"+n+"\n");
			if(n==1){
				primary_key_map[index]=hrefcss_green2;
			}else if(n==2){
				primary_key_map[index]=hrefcss_darkorange;
			}else if(n==3){
				primary_key_map[index]=hrefcss_orange;
			}else if(n==4){
				primary_key_map[index]=hrefcss_purple;
			}	
		}

		array(string) index_array=indices(primary_key_map);
		foreach(index_array,string index){
			if(search(link_name,index)!=-1){
				return primary_key_map[index];
			}
				
		}
	};
	if(err)
		return hrefcss;
	return hrefcss;
}
string filter(string s)
{
	////////////////20060309 by qianglee
	//简单加密用户信息
	string txd = "";
	string userid = this_player()->name;
	string passwd = this_player()->password;
	//werror("==== userid = "+userid+"========\n");
	/*
	if(userid&&passwd)
	{
		//进行密码的简单加密
		string uid="";
		string pid="";
		for(int i=0;i<sizeof(userid);i++)
		{
			if(i/2==0)
				uid += sprintf("%c",userid[i]+2);//简单加密
			else
				uid += sprintf("%c",userid[i]+1);//简单加密
		}
		for(int j=0;j<sizeof(passwd);j++)
		{
			if(j/2==0)
				pid += sprintf("%c",passwd[j]+1);//简单加密
			else
				pid += sprintf("%c",passwd[j]+2);//简单加密
		}
		txd = uid+"~"+pid;
		txd = decode(txd);
	}
	else
		txd = "xxxx~yyyy";
	*/
	txd = userid+"~"+passwd;
	txd = decode(txd);
	
/*使用DES算法，对txd进行加密操作 Evan added 20081008
//	txd = this_player()->command("desEncryptor");
	string deskey = Nettle.DES_Info()->fix_parity(DES_KEY);
	werror("==== deskey = "+ deskey +"========\n");
	werror("==== txd0 = "+txd+"========\n");
	txd = Crypto.DES.encrypt(deskey,txd);
	werror("==== txd1 = "+txd+"========\n");
	//txd = Crypto.DES.decrypt(deskey,txd);
	//werror("==== txd2 = "+txd+"========\n");
//end of Evan added 20081008
*/	
	/////////////////////
	string usid = "";
	usid = this_player()->query_userip();
	if(usid)
		usid = decode(usid);
	else
		usid = "xxxxyyyy";
	///////////////20060309 by qianglee

	if(url==0){
		out+=s;
		return "";
	}
	string d;
	while(s&&sizeof(s)){
		if(sscanf(s,"%s[",d)){
			out+=decode(d);
			s=s[sizeof(d)..];
		}
		else{
			out+=decode(s);
			s=0;
			break;
		}
		string type,name,cmd,acmd,href;
		string buf;
		string max_size,fvalue;
		if(sscanf(s,"[%s]",buf)){
			if(sizeof(buf)&&buf[0]=='<'){
				out+=buf;
			}
			else if(sscanf(buf,"submit %s:%s ...",name,cmd)==2){
				//cmd=replace(cmd," ","+");
				//add for cmd=+num
				if(in_form==0){
					out+=sprintf("<form action='%s' method='post'>",url);
					in_form=1;
				}
				//out+=sprintf("<input type='hidden' name='_cmd' value='%s'><input type='submit' value='"+name+"'></form>",cmd);
				out+=sprintf("<input type='hidden' name='_cmd' value='%s'><input type='hidden' name='_usid' value='%s'><input type='hidden' name='_txd' value='%s'><input type='submit' value='"+name+"'></form>",cmd,usid,txd);
				in_form=0;
			}
			else if(sscanf(buf,"%s %s:..*%s...*%s",type,name,fvalue,max_size)==4||sscanf(buf,"%s:..*%s...*%s",name,fvalue,max_size)==3){
				
				//add for cmd=+num
				if(in_form==0){
					out+=sprintf("<form action='%s' method='post'>",url);
					in_form=1;
				}
				input+=({name});
				if(type=="passwd")
					out+=sprintf("<input type=password name='%s' size='%s' value='%s'><input type='hidden' name='_usid' value='%s'><input type='hidden' name='_txd' value='%s'>",name,max_size,fvalue,usid,txd);
				else
					out+=sprintf("<input name='%s' size='%s' value='%s'><input type='hidden' name='_usid' value='%s'><input type='hidden' name='_txd' value='%s'>",name,max_size,fvalue,usid,txd);
			}
			else if(sscanf(buf,"%s %s:...",type,name)==2||sscanf(buf,"%s:...",name)==1){
				
				//add for cmd=+num
				if(in_form==0){
					out+=sprintf("<form action='%s' method='post'>",url);
					in_form=1;
				}
				input+=({name});
				if(type=="passwd")
					out+=sprintf("<input type=password name='%s'><input type='hidden' name='_usid' value='%s'><input type='hidden' name='_txd' value='%s'>",name,usid,txd);
				else
					out+=sprintf("<input name='%s'><input type='hidden' name='_usid' value='%s'><input type='hidden' name='_txd' value='%s'>",name,usid,txd);
			}
			else if(sscanf(buf,"%s:%s...",type,cmd)==2||sscanf(buf,"%s...",cmd)==1){
				//cmd=replace(cmd," ","+");
				//add for cmd=+num
				if(in_form==0){
					out+=sprintf("<form action='%s' method='post'>",url);
					in_form=1;
				}
				out+=sprintf("<input type='hidden' name='_cmd' value='%s'><input name='_arg'><input type='hidden' name='_usid' value='%s'><input type='hidden' name='_txd' value='%s'><input type='submit' value='提交'></form>",cmd,usid,txd);
				in_form=0;

			}
			else if(sscanf(buf,"url %s:%s",name,href)==2){
				//add for cmd=+num
				out+="<a href=\""+href+"\" class=\""+get_right_href_css(name)+"\">"+name+"</a>\n";
			}
			else if(sscanf(buf,"img %s:%s",name,cmd)==2){
				
				//add for cmd=+num
				if(sscanf(name,"%s %s",type,name)!=2){
					type="gif";
				};
				cmd=replace(cmd," ","+");
				out+="<img src=\""+url+"?_filter="+type+"&_cmd="+cmd+"\" alt=\""+name+"\">";
			}
			else if(sscanf(buf,"imgurl %s:%s",name,href)==2){
				
				//add for cmd=+num
				out+="<img src=\""+href+"\" alt=\""+name+"\">";
			}
			else if(sscanf(buf,"miniimg %s:%s",name,href)==2){
				
				//add for cmd=+num
				out+="<img src=\""+href+"\" alt=\""+name+"\" height=\"20\" width=\"20\" align =\"middle\">";
			}
			else if(sscanf(buf,"aimg %s:%s;%s",name,acmd,cmd)==3){
				
				//add for cmd=+num
				if(sscanf(name,"%s %s",type,name)!=2){
					type="gif";
				};
				cmd=replace(cmd," ","+");
				acmd=replace(acmd," ","+");
				out+="<a href=\""+url+"?_cmd="+cmd+"\" class=\""+get_right_href_css(name)+"\"><img src=\""+url+"?_filter="+type+"&_cmd="+acmd+"\" alt=\""+name+"\"/></a>";
			}
			else if(sscanf(buf,"%s:%s",name,cmd)==2){
				int d;
				if(sscanf(name,"%s{%d}",name,d)==2){
					//name=d+")"+name;
				}
				//add for cmd=+num
				if(this_player()["hide"])
						cmd=this_player()->hide(cmd);
				string s=replace(cmd," ","+");
				out+=sprintf("<a href='%s?_txd=%s&amp;_usid=%s&amp;_cmd=%s' class=\'"+get_right_href_css(name)+"\'>%s</a>",url,txd,usid,s,name);
/*				if(in_form==0){
					out+=sprintf("<form action='%s' method='post'>",url);
					in_form=1;
				}
				out+=sprintf("<form action='%s' method='post'>",url);
				out+=sprintf("<input type='hidden' name='_cmd' value='%s'><input name='_arg'><input type='submit' value='%s'></form>",cmd,name);
				in_form=0;*/
			}
		}
		if(sscanf(s,"%s]",d)){
			s=s[sizeof(d)+1..];
		}
		else{
			s="";
		}
	}
	return "";
}
void setvar(string var,string data)
{
	out=var+"="+data+"\n"+out;
}
