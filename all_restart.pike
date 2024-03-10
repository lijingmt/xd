#!/usr/local/bin/pike8
#define IP "127.0.0.1"
#define PORT 13800 
#define PROJECT "gamelib" 
#define LOG "/usr/local/games/xiand"

int main(int num,array(string) args)
{
	write("==== startup game begin\n");
	mixed err1=catch{
		write("---- out side call shutdown begin\n");
		object con=Stdio.File();
		con->connect(IP,PORT);
		con->write("login_fee "+PROJECT+" fhwl111\n");
		////////////////////////////
		con->write("shutdown\n");
		con->write("quit\n");
		con->close();
		write("---- shutdown ok\n");
	};
	if(!err1)
		write("---- process is working,out side call shutdown ok\n");
	else
		write("---- !!!! wrong !! process is not on working ,out side call shutdown fail !!!!\n");

	delay(2);//延迟5秒

	Process.system(LOG+"/startup.sh");

	write("==== startup game end\n");
}
