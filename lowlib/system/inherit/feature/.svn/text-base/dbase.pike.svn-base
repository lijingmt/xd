mapping data=([]);
static mapping data_tmp=([]);
static string tmp;

mixed `[](string key,void|int n)
{
	if(n){
		return ::`[](key,n);
	}
	if(key&&sizeof(key)&&key[0]=='/'){
		array a=key[1..]/"/";
		if(!data)data=([]);
		mapping m=data;
		if(a[0]=="tmp")
			m=data_tmp;
		for(int i=0;i<sizeof(a)-1;i++){
			string s=a[i];
			if(!mappingp(m[s])){
				return 0;
			}
			m=m[s];
		}
		return m[a[-1]];
	}else{
		return `->(this_object(),key);
	}
}
mixed `[]=(string key, mixed val,void|int n)
{
	if(n){
		return ::`[]=(key,val,n);
	}
	if(key&&sizeof(key)&&key[0]=='/'){
		array a=key[1..]/"/";
		mapping m=data;
		if(a[0]=="tmp")
			m=data_tmp;
		for(int i=0;i<sizeof(a)-1;i++){
			string s=a[i];
			if(!mappingp(m[s])){
				m[s]=([]);
			}
			m=m[s];
		}
		return m[a[-1]]=val;

	}
	else{
		return `->=(this_object(),key,val);
	}
}
mixed _m_delete(string key)
{
	if(key&&sizeof(key)&&key[0]=='/'){
		array a=key[1..]/"/";
		mapping m=data;
		if(a[0]=="tmp")
			m=data_tmp;
		for(int i=0;i<sizeof(a)-1;i++){
			string s=a[i];
			if(!mappingp(m[s])){
				m[s]=([]);
			}
			m=m[s];
		}
		return m_delete(m,a[-1]);
	}
	else{
		return 0;
	}
}
void set_tmp(string s)
{
	tmp=s;
}
int cat_tmp()
{
	write(tmp);
	return 1;
}
string query_tmp()
{
	return tmp;
}
