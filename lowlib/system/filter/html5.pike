#include <globals.h>
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
	out+= "<title>《天下仙道网游》</title>\n";
	out+= "<link href=\"includes/intro.css\" rel=\"stylesheet\" type=\"text/css\"/>\n";
	out+= "</head>\n";
	out+= "<body>\n"; 
	out+= "<div>\n"; 
	
	return "";
}
string net_dead()
{
	//werror("\n555555555555555555555 html5.pike net_dead call 555555555555555555555555555555\n");
	//out+="</html>";
	out+="</body></html>";
	input=({});
	string o=out;
	out="";
	return o;
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
			else if(sscanf(buf,"submit %s:%s...",name,cmd)==2){
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
				out+=sprintf("<input type='hidden' name='_cmd' value='%s'><input name='_arg'><input type='hidden' name='_usid' value='%s'><input type='hidden' name='_txd' value='%s'><input type='submit' value='确定'></form>",cmd,usid,txd);
				in_form=0;

			}
			else if(sscanf(buf,"url %s:%s",name,href)==2){
				//add for cmd=+num
				out+="<a href=\""+href+"\">"+name+"</a>\n";
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
				out+="<a href=\""+url+"?_cmd="+cmd+"\"><img src=\""+url+"?_filter="+type+"&_cmd="+acmd+"\" alt=\""+name+"\"/></a>";
			}
			else if(sscanf(buf,"%s:%s",name,cmd)==2){
				int d;
				if(sscanf(name,"%s{%d}",name,d)==2){
					//name=d+")"+name;
				}
				//add for cmd=+num
				string s=replace(cmd," ","+");
				out+=sprintf("<a href='%s?_txd=%s&amp;_usid=%s&amp;_cmd=%s'>%s</a>",url,txd,usid,s,name);
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
