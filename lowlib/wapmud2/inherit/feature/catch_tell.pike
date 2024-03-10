#define MAX_MSGS 10 
mapping(string:array(string))|array msgs=([]);
void clean_catch_tell(void|string channel){
	m_delete(msgs,channel);
}
void catch_tell(string str,string channel) {
	int n;
	if(!msgs){
		msgs=([]);
	}
	if(arrayp(msgs)){
		msgs=([0:msgs]);
	}
	if(msgs[channel]==0)
		msgs[channel]=({});
	n=sizeof(msgs[channel]);
	if(n>0&&sizeof(msgs[channel][n-1])>0&&msgs[channel][n-1][sizeof(msgs[channel][n-1])-1]!='\n'){
		msgs[channel][n-1]+=str;
	}else{
		msgs[channel]+=({str});
	}
	if(sizeof(msgs[channel])>MAX_MSGS){
		msgs[channel]=msgs[channel][1..];
	}
}
//第二个参数指定读取的条数
string drain_catch_tell(void|string channel,void|int num){
	string out="";
	if(arrayp(msgs)){
		msgs=([0:msgs]);
	}
	if(msgs[channel]==0){
		return "";
	}
	int beginNum=0;
	if(num) beginNum=sizeof(msgs[channel])-num;
	if(beginNum<0)beginNum=0;
	for(int i=beginNum;i<sizeof(msgs[channel]);i++){
		out+=msgs[channel][i];
	}
		clean_catch_tell(channel);
	return out;
}
