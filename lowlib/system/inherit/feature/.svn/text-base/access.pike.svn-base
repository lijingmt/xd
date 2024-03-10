mixed `->(string key)
{
	string var;
	if(zero_type(::`[](key,2))==1){
		if(sscanf(key,"query_%s",var)){
			if(zero_type(::`[](var,2))!=1){
				return lambda(){
					return ::`[](var,2);
				};
			}
		}
		else if(sscanf(key,"set_%s",var)){
				return lambda(mixed val){
					return ::`[]=(var,val,2);
				};
		}
	}
	if(functionp(::`[]("query_"+key,2))){
			return ::`[]("query_"+key,2)();
	}
	else{
		return ::`[](key,2);
	}
}
mixed `->=(string key,mixed val)
{
	if(functionp(::`[]("set_"+key,2))){
		::`[]("set_"+key,2)(val);
		return val;
	}
	else{
		return ::`[]=(key,val,2);
	}
}

