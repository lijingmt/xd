#include <globals.h>
inherit LOW_FILTER;

static private string headerU=
"<wml> <head> <meta forua=\"true\" http-equiv=\"Cache-Control\" content=\"max-age=0\"/> </head>";
//static private string headerG="ContentType=text/vnd.wap.wml; charset=gb2312\nCharset=gb2312\n\n"
//"<?xml version=\"1.0\" encoding=\"gb2312\"?> <!DOCTYPE wml PUBLIC \"-//WAPFORUM//DTD WML 1.1//EN\" \"http://www.wapforum.org/DTD/wml_1.1.xml\"> <wml> <head> <meta forua=\"true\" http-equiv=\"Cache-Control\" content=\"max-age=0\"/> </head>";
static private string headerG="ContentType=text/vnd.wap.wml; charset=utf-8\nCharset=utf-8\n\n"
"<?xml version=\"1.0\" encoding=\"utf-8\"?> <!DOCTYPE wml PUBLIC \"-//WAPFORUM//DTD WML 1.1//EN\" \"http://www.wapforum.org/DTD/wml_1.1.xml\"> <wml> <head> <meta forua=\"true\" http-equiv=\"Cache-Control\" content=\"max-age=0\"/> </head>";
static private string footer=
"</wml>";

array(string) input;
string out;
void create()
{
	::create();
	input=({});
	out="";
}
string setup(string __url)
{
	url=__url; //url=/xiand/main.jsp
	return "";
}
string string_to_wap(string s)
{
	string out="";
	for(int i=0;i<sizeof(s);i++){
		if(s[i]>0&&s[i]<=127){
			out+=s[i..i];
		}
		else{
			out+=string_to_utf8(s[i..i]);
		}
	}
	return out;
}
string net_dead()
{
	//werror("\n555555555555555555555 wml.pike net_dead call 555555555555555555555555555555\n");
	string stimer="<card title=\""+decode(title)+"\">";
	/*
	if(this_player()->wml_timer_interval&&(this_player()->wml_timer_cmd||this_player()->wml_timer_url)){
		if(this_player()->wml_timer_cmd){
			if(this_player()["hide"])
				stimer="<card  title=\""+decode(title)+"\" ontimer=\""+url+"?_cmd="+replace(this_player()->hide(this_player()->wml_timer_cmd),([" ":"+","&":"&amp;"]))+"\"> <timer value=\""+this_player()->wml_timer_interval+"\"/>";
			else
				stimer="<card  title=\""+decode(title)+"\" ontimer=\""+url+"?_cmd="+this_player()->wml_timer_cmd+"\"> <timer value=\""+this_player()->wml_timer_interval+"\"/>";
		}
		else{
			stimer="<card  title=\""+decode(title)+"\" ontimer=\""+replace(this_player()->wml_timer_url,([" ":"+","&":"&amp;"]))+"\"> <timer value=\""+this_player()->wml_timer_interval+"\"/>";
		}
	}
	*/
	string s;
	s=string_to_wap(headerU+stimer+"<p>"+out+"</p></card>"+footer);
	input=({});
	out="";
	//werror("\n555555555555555555555 wml.pike net_dead end 555555555555555555555555555555\n");
	return s;
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
private string decode(string s,void|int skip_filter)
{
	string out="";
	int last_char;
	for(int i=0;i<sizeof(s);i++){
		if(!skip_filter&&s[i]=='%'){
			if(i<sizeof(s)-1){
				if(s[i+1]=='%'){
					out+='%';
					i++;
				}
				else if(s[i+1]>='0'&&s[i+1]<='9'||s[i+1]>='a'&&s[i+1]<='f'||s[i+1]>='A'&&s[i+1]<='F')
				{
					int n;
					sscanf(s[i+1..i+2],"%x",n);
					out+=sprintf("%c",n);
					i+=2;
				}
				else{
					out+="%";
				}
			}
		}
		else if(s[i]>=0&&s[i]<128){
			if(last_char=='\n'&&s[i]=='\n'){
			}
			else{
				if(skip_filter){
					out+=s[i..i];
				}
				else{
					out+=replace(s[i..i],(["&":"&amp;","<":"&lt;",">":"&gt;","\n":"<br/>"]));
				}
			}
		}
		else{
			out+=Locale.Charset.decoder("euc_cn")->feed(s[i..i+1])->drain();
			i++;
		}
		last_char=s[i];
	}
	return out;
}
string filter(string s)
{
	string txd = "";
	string userid = this_player()->name;
	string passwd = this_player()->password;
	txd = userid+"~"+passwd;
	txd = decode(txd);
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
		//werror("string s = %s\n",s);
		if(sscanf(s,"%s[",d)){
			out+=decode(d);
			s=s[sizeof(d)..];
		}
		else{
			out+=decode(s);
			s=0;
			break;
		}
		string type,name,cmd,acmd,href,ahref;
		string data;
		string buf;
		string fvalue;
		if(sscanf(s,"[%s]",buf)){
			if(upper_case(buf)=="OL"){
				out+="<ol>";
			}
			else if(upper_case(buf)=="/OL"){
				out+="</ol>";
			}
			if(sizeof(buf)&&buf[0]=='<'){
				out+=decode(buf,1);
			}
			if(sscanf(buf,"wml %s",data)){
				out+=decode(buf,1);
			}
			else if(sscanf(buf,"prev %s:%s",name,cmd)){
				if(cmd&&cmd!=""){
					if(this_player()["hide"])
						cmd=this_player()->hide(cmd);
					cmd=replace(cmd," ","+");//瞎改的，目的吧+去掉
					out+=sprintf("<a href=\"%s?_txd=%s&amp;_usid=%s&amp;_cmd=%s\">%s</a>",url,txd,usid,cmd,decode(name));
					out+="</p><do type=\"prev\" label=\""+decode(name)+"\"><go href=\""+url+"?_txd="+txd+"&amp;_usid="+usid+"&amp;_cmd="+cmd+"\"/></do><p>";
				}
				else{
					out+=sprintf("<anchor><prev/>"+decode(name)+"</anchor>");
					out+="</p><do type=\"prev\" label=\""+decode(name)+"\"><prev/></do><p>";
				}
			}
			else if(sscanf(buf,"submit %s:%s...",name,cmd)==2){
				//werror("\narg="+buf+"\n");
				if(this_player()["hide"])
					cmd=this_player()->hide(cmd);
				out+="<anchor><go href=\""+url+"\">";
				out+="<postfield name=\"_cmd\" value=\""+cmd+"\" />";
				out+="<postfield name=\"_txd\" value=\""+txd+"\" />";
				out+="<postfield name=\"_usid\" value=\""+usid+"\" />";
				foreach(input,string s){
					//werror("******s="+s+"******\n");
					out+="<postfield name=\""+s+"\" value=\"$("+s+")\" />";
				}
				out+="</go>"+decode(name)+"</anchor>\n";
			}
			else if(sscanf(buf,"select %s %s:%s..*%s...",name,data,cmd,fvalue)==4){
				string ok="确定";
				sscanf(name,"%s{%s}",ok,name);
				if(cmd=="")
					input+=({name});
				array(string) options=data/" ";
				out+="<select name=\""+name+"\" value=\""+decode(fvalue)+"\">";
				int n;
				foreach(options,string s){
					string view=s;
					string value=n+++"";
					sscanf(s,"%s{%s}",view,value);
					out+="<option value=\""+value+"\">"+decode(view)+"</option>";
				}
				out+="</select>";
				if(cmd!=""){
					if(this_player()["hide"])
						cmd=this_player()->hide(cmd);
					out+="<anchor><go href=\""+url+"\">";
					out+="<postfield name=\"_cmd\" value=\""+cmd+"\" />";
					out+="<postfield name=\"_txd\" value=\""+txd+"\" />";
					out+="<postfield name=\"_usid\" value=\""+usid+"\" />";
					out+="<postfield name=\""+name+"\" value=\"$("+name+")\" />";
					out+="</go>"+decode(ok)+"</anchor>\n";
				}
			}
			else if(sscanf(buf,"select %s %s:%s...",name,data,cmd)==3){
				string ok="确定";
				sscanf(name,"%s{%s}",ok,name);
				if(cmd=="")
					input+=({name});
				array(string) options=data/" ";
				out+="<select name=\""+name+"\">";
				int n;
				foreach(options,string s){
					string view=s;
					string value=n+++"";
					sscanf(s,"%s{%s}",view,value);
					out+="<option value=\""+value+"\">"+decode(view)+"</option>";
				}
				out+="</select>";
				if(cmd!=""){
					if(this_player()["hide"])
						cmd=this_player()->hide(cmd);
					out+="<anchor><go href=\""+url+"?_txd="+txd+"\">";
					out+="<postfield name=\"_cmd\" value=\""+cmd+"\" />";
					out+="<postfield name=\"_usid\" value=\""+usid+"\" />";
					out+="<postfield name=\""+name+"\" value=\"$("+name+")\" />";
					out+="</go>"+decode(ok)+"</anchor>\n";
				}
			}
			else if(sscanf(buf,"%s %s:...",type,name)==2||sscanf(buf,"%s:...",name)==1){
				//werror("\nbuf="+buf+"\n");
				input+=({name});
				if(type=="passwd")
					out+=sprintf("<input type=\"password\" name=\"%s\" maxlength=\"127\" emptyok=\"false\" />",name);
				else if(type=="int")
					out+=sprintf("<input format=\"*N\" name=\"%s\" maxlength=\"127\" emptyok=\"false\" />",name);
				else
					out+=sprintf("<input name=\"%s\" maxlength=\"127\" emptyok=\"false\" />",name);
			}
			else if(sscanf(buf,"%s %s:..*%s...",type,name,fvalue)==3||sscanf(buf,"%s:..*%s...",name,fvalue)==2){
				input+=({name});
				if(type=="passwd")
					out+=sprintf("<input type=\"password\" name=\"%s\" maxlength=\"127\" emptyok=\"false\" value=\"%s\"/>",name,decode(fvalue));
				else if(type=="int")
					out+=sprintf("<input format=\"*N\" name=\"%s\" maxlength=\"127\" emptyok=\"false\" value=\"%s\"/>",name,decode(fvalue));
				else
					out+=sprintf("<input name=\"%s\" maxlength=\"127\" emptyok=\"false\" value=\"%s\"/>",name,decode(fvalue));
			}
			else if(sscanf(buf,"%s:%s...",type,cmd)==2||sscanf(buf,"%s...",cmd)==1){
				if(this_player()["hide"])
					cmd=this_player()->hide(cmd);
				/////////////////////////////////////////////////////////////
				if(type=="passwd") //[set_filter wml /xiand00/main.jsp xdtest]
					out+=sprintf("<input type=\"password\" name=\"zarg\" maxlength=\"127\" emptyok=\"false\" />",name);
				else if(type=="int")
					out+=sprintf("<input format=\"*N\" name=\"zarg\" maxlength=\"127\" emptyok=\"false\" />",name);
				else
					out+=sprintf("<input name=\"zarg\" maxlength=\"127\" emptyok=\"false\" />",name);
				out+="<anchor><go href=\""+url+"\">";
				out+="<postfield name=\"_cmd\" value=\""+cmd+"\" />";
				out+="<postfield name=\"_txd\" value=\""+txd+"\" />";
				out+="<postfield name=\"_usid\" value=\""+usid+"\" />";
				out+="<postfield name=\"_arg\" value=\"$zarg\" />";
				out+="</go>"+decode("确定")+"</anchor>\n";
			}
			else if(sscanf(buf,"%s:%s..*%s...",type,cmd,fvalue)==3||sscanf(buf,"%s..*%s...",cmd,fvalue)==3){
				if(this_player()["hide"])
					cmd=this_player()->hide(cmd);
				if(type=="passwd")
					out+=sprintf("<input type=\"password\" name=\"zarg\" maxlength=\"127\" emptyok=\"false\" value=\"%s\"/>",name,decode(fvalue));
				else if(type=="int")
					out+=sprintf("<input format=\"*N\" name=\"zarg\" maxlength=\"127\" emptyok=\"false\" value=\"%s\"/>",name,decode(fvalue));
				else
					out+=sprintf("<input name=\"zarg\" maxlength=\"127\" emptyok=\"false\" value=\"%s\"/>",name,decode(fvalue));
				/////////////////////////////////////////////////////////////
				out+="<anchor><go href=\""+url+"\">";
				out+="<postfield name=\"_cmd\" value=\""+cmd+"\" />";
				out+="<postfield name=\"_txd\" value=\""+txd+"\" />";
				out+="<postfield name=\"_usid\" value=\""+usid+"\" />";
				out+="<postfield name=\"_arg\" value=\"$zarg\" />";
				out+="</go>"+decode("确定")+"</anchor>\n";
			}
			else if(sscanf(buf,"url %s:%s",name,href)==2){
				int d;
				if(sscanf(name,"%s{%d}",name,d)==2){
					//name=d+")"+name;
				}
				out+="<a href=\""+replace(href,([" ":"+","&":"&amp;"]))+"\">"+decode(name)+"</a>\n";
			}
			else if(sscanf(buf,"img %s:%s",name,cmd)==2){
				if(sscanf(name,"%s %s",type,name)!=2){
					type="wbmp";
				};
				//werror(type+" "+name+"\n");
//never hide img cmd		if(this_player()["hide"])
//					cmd=this_player()->hide(cmd);
				cmd=replace(cmd," ","+");
				out+="<img src=\""+url+"?_filter="+type+"&amp;_cmd="+cmd+"\" alt=\""+decode(name)+"\"/>";
			}
			else if(sscanf(buf,"imgurl %s:%s",name,href)==2){
				out+="<img src=\""+replace(href,([" ":"+","&":"&amp;"]))+"\" alt=\""+decode(name)+"\"/>";
			}
			else if(sscanf(buf,"miniimg %s:%s",name,href)==2){
				out+="<img src=\""+replace(href,([" ":"+","&":"&amp;"]))+"\" alt=\""+decode(name)+"\" height=\"20\" width=\"20\" align =\"middle\"/>";
			}
			else if(sscanf(buf,"aimg %s:%s;%s",name,acmd,cmd)==3){
				if(sscanf(name,"%s %s",type,name)!=2){
					type="wbmp";
				};
				//werror(type+" "+name+"\n");
				if(this_player()["hide"]){
					cmd=this_player()->hide(cmd);
//					acmd=this_player()->hide(acmd);
				}
				cmd=replace(cmd," ","+");
				acmd=replace(acmd," ","+");
				out+="<anchor><go href=\""+url+"?_cmd="+cmd+"\"/><img src=\""+url+"?_filter="+type+"&amp;_cmd="+acmd+"\" alt=\""+decode(name)+"\"/></anchor>";
			}
			else if(sscanf(buf,"aimgurl %s:%s;%s",name,ahref,cmd)==3){
				if(sscanf(name,"%s %s",type,name)!=2){
					type="wbmp";
				};
				if(this_player()["hide"]){
					cmd=this_player()->hide(cmd);
//					acmd=this_player()->hide(acmd);
				}
				//werror(type+" "+name+"\n");
				cmd=replace(cmd,([" ":"+","&":"&amp;"]));
				ahref=replace(ahref,([" ":"+","&":"&amp;"]));
				out+="<anchor><go href=\""+url+"?_cmd="+cmd+"\"/><img src=\""+ahref+"\" alt=\""+decode(name)+"\"/></anchor>";
			}
			else if(sscanf(buf,"option %s:%s",name,cmd)==2){
				if(this_player()["hide"])
					cmd=this_player()->hide(cmd);
				cmd=replace(cmd," ","+");
				out+=sprintf("<option onpick=\"%s?_cmd=%s\">%s</option>",url,cmd,decode(name));
			}
			else if(sscanf(buf,"%s:%s",name,cmd)==2){
				int d;
				if(sscanf(name,"%s{%d}",name,d)==2){
					//name=d+")"+name;
				}
				//string s=Protocols.HTTP.http_encode_string(cmd);
				if(this_player()["hide"])
					cmd=this_player()->hide(cmd);
				cmd=replace(cmd," ","+");
				out+=sprintf("<a href=\"%s?_txd=%s&amp;_usid=%s&amp;_cmd=%s\">%s</a>",url,txd,usid,cmd,decode(name));
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
