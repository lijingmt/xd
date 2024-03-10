static array(array) items=({});//({program,object,_flushtime,last_time=time()});
void add_items(array(string|program) _items){
	foreach(_items,string|program s){
		object ob=new(s);
		//({内存唯一副本，内存中的拷贝，该物件刷新时间，当前时间})
		items+=({({((program)s),ob,ob->_flushtime,time()})});
		ob->move(this_object());
	}
}
void reset_items()
{
	foreach(items,array a){
		if(a[1]==0){
			//如果该Npc有刷新时间，并且没有到刷新时间，不予clone并移动到该房间
			if((int)a[2]>=1){
				if(time()-(int)a[3]>=(int)a[2]){
					a[1]=new(a[0]);
					a[3]=time();
					a[1]->move(this_object());
				}
			}
			else{
				a[1]=new(a[0]);
				a[1]->move(this_object());
			}
		}
		else{
			if(a[1]["is_npc"]&&!a[1]->in_combat&&!a[1]["randomGo"])
				a[1]->move(this_object());
		}
	}
}
void flush_items(object item)
{
	foreach(items,array tmp_arr){
		if(tmp_arr && sizeof(tmp_arr)){
			if(tmp_arr[1]==item){
				tmp_arr[3]=time();
			}
		}
	}
}
