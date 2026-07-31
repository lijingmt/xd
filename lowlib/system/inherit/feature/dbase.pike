mapping data=([]);
mapping data_tmp=([]);
string tmp;

// 序列化层使用的公开原始变量读取口。旧实现从对象外调用
// protected `[] 会被 Pike 9 拒绝，随后退回 query_xxx，导致动态界面函数在存档时执行。
mixed query_raw_variable(string key)
{
	return ::`[](key,2);
}


protected mixed `[](string key, void|mixed n)
{
	// Pike 9: Second parameter controls access mode
	// n == "RAW" means bypass operator overload, access raw variable value directly
	// This is used by pikenv_save_object() to prevent saving computed property values
	if(stringp(n) && n == "RAW"){
		// Return raw variable value directly, without calling -> operator
		return ::`[](key, 2);
	}

	if(key&&sizeof(key)&&key[0]=='/'){
		array a=key[1..]/"/";
		if(!data)data=([]);
		if(!data_tmp)data_tmp=([]);
		mapping m=data;
		int start_idx=0;
		if(sizeof(a)>0&&a[0]=="tmp"){
			m=data_tmp;
			start_idx=1;
		}
		for(int i=start_idx;i<sizeof(a)-1;i++){
			string s=a[i];
			if(!mappingp(m[s])){
				return 0;
			}
			m=m[s];
		}
		return m[a[-1]];
	}else{
		// 非 RAW 模式：使用 -> 操作符（会调用 query_xxx 方法）
		// 但需注意：name_cn 等变量会在 save/restore 时累积后缀
		// 这是一个已知的设计限制，需要在使用 query_xxx() 时注意不要累积修改
		return `->(this_object(),key);
	}
}

protected mixed `[]=(string key, mixed val, void|mixed n)
{
	// Pike 9: Third parameter controls access mode
	// n == "RAW" means bypass operator overload, set raw variable directly
	if(stringp(n) && n == "RAW"){
		// Set raw variable value directly, without calling ->= operator
		return ::`[]=(key,val,2);
	}
	if(key&&sizeof(key)&&key[0]=='/'){
		array a=key[1..]/"/";
		if(!data)data=([]);
		if(!data_tmp)data_tmp=([]);
		mapping m=data;
		int start_idx=0;
		if(sizeof(a)>0&&a[0]=="tmp"){
			m=data_tmp;
			start_idx=1;
		}
		for(int i=start_idx;i<sizeof(a)-1;i++){
			string s=a[i];
			if(!mappingp(m[s])){
				m[s]=([]);
			}
			m=m[s];
		}
		return m[a[-1]]=val;

	}
	else{
		// 非 RAW 模式：使用 ->= 操作符（保持向后兼容）
		return `->=(this_object(),key,val);
	}
}

// Public method to delete values from the dbase path storage
int m_delete_foruser(string key)
{
	if(key&&sizeof(key)&&key[0]=='/'){
		array a=key[1..]/"/";
		if(!data)data=([]);
		if(!data_tmp)data_tmp=([]);
		mapping m=data;
		int start_idx=0;
		if(sizeof(a)>0&&a[0]=="tmp"){
			m=data_tmp;
			start_idx=1;
		}
		for(int i=start_idx;i<sizeof(a)-1;i++){
			string s=a[i];
			if(!mappingp(m[s])){
				m[s]=([]);
			}
			m=m[s];
		}
		m_delete(m,a[-1]);
		return 1;
	}
	return 0;
}

protected mixed _m_delete(string key)
{
	if(key&&sizeof(key)&&key[0]=='/'){
		array a=key[1..]/"/";
		if(!data)data=([]);
		if(!data_tmp)data_tmp=([]);
		mapping m=data;
		int start_idx=0;
		if(sizeof(a)>0&&a[0]=="tmp"){
			m=data_tmp;
			start_idx=1;
		}
		for(int i=start_idx;i<sizeof(a)-1;i++){
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

/*
string test;
void main()
{
	this_object()["/tmp/xixi/haha"]="faint";
	write(this_object()["/tmp/xixi"]["haha"]);
	this_object()["test"]="faint";
	write(this_object()["test"]);
}
*/
