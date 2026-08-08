#include <command.h>

int main(string arg)
{
	string path,user_name,maintenance_token;
	string expected_token = getenv("XIAND_MAINTENANCE_TOKEN") || "";
        if(arg&&(sscanf(arg,"%s %s %s",path,user_name,
		maintenance_token)==3))
        {
		if(path!="gamelib" || sizeof(expected_token)<24 ||
		   maintenance_token!=expected_token){
			write("error");
			return 1;
		}
		if(!user_name)
		{
			write("error");
			return 1;
		}
		else if( sizeof(user_name)<2 )
		{
			write("error");
			return 1;
		}
		for(int i=0;i<sizeof(user_name);i++)
		{
			if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
			{

			}
			else
			{
				write("error");
				return 1;
			}
		}
		//鍙栧嚭鍦ㄧ嚎鐢ㄦ埛鍒楄〃
		if(user_name!="managerTxAll20060520")
		{
			write("error");
			return 1;
		}
		else
		{
			//write("login game sucess! can get online users!\n");	
			
			array(object) list;
			list = users();
			int count = 99999;
			count = sizeof(list);
			string tmp = ""+count;	
			write(tmp);
			
			return 1;
		}
	}
	else
	{
		write("error");
		return 1;
	}
	return 1;
}
