#define HIDDEN_SIZE 2000
#include <globals.h>
static array(string) hidden=allocate(HIDDEN_SIZE);
read_write(hidden);
static int hidden_pos;
read_write(hidden_pos);
static int reset_flag=1;
read_write(reset_flag);
string hide(string s)
{
	if(hidden==0){
		hidden=allocate(HIDDEN_SIZE);
	}
	if(reset_flag){
		for(int i=0;i<sizeof(hidden);i++){
			hidden[i]="flushview";
		}
		if(reset_flag==2){
			hidden_pos=0;
		}
		reset_flag=0;
	}
	if(hidden_pos>=sizeof(hidden)){
		hidden_pos=0;
	}
	hidden[hidden_pos]=s;
	hidden_pos++;
	return hidden_pos-1+" ";
}

void reset_hidden(void|int no_roll)
{
	if(no_roll){
		reset_flag=2;
	}
	else{
		reset_flag=1;
	}
}
