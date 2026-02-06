private array heart_array=({});//({({function,interval,left,mixed...args})})
void add_heart_beat(function f,void|int interval,void|mixed...args){
	if(f==0){
		//werror("add_heart_beat with NULL function.\n");
		return;
	}
	else{
	}
	if(interval==0)
		interval=1;
	heart_array+=({({f,interval,0,args})});
}
void heart_beat(){
	for(int i=0;i<sizeof(heart_array);i++){
		array a=heart_array[i];
		a[2]++;
		if(a[2]==a[1]){
			a[2]=0;
			if(a[0]==0){
				//werror("NULL function in heart_beat.\n");
				//werror("i=%d\n",i);
				//werror("name=%s\n",this_object()->name);
				//werror("size=%d\n",sizeof(heart_array));
			}
			else{
				a[0](@a[3]);
			}
		}
	}
}
