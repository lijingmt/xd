//({({function,mixed...args})})
private array init_array=({});
void add_init(function f,void|mixed...args){
	init_array+=({({f,args})});
}
void init(){
	foreach(init_array,mixed a){
		a[0](@a[1]);
	}
}
