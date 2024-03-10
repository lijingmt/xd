#!/usr/local/bin/pike
#define IP "127.0.0.1"
#define PORT 5499
#define PROJECT "gamelib" 
#define LOG "/usr/local/games/xiand9/log/fee_log/feelog"

int main(int num,array(string) args)
{
	if(num==4 || num==5)
	{
		int fee = 1;	
		int yushi_level = 2;
		string yushi_type = "";
		string mobile="13910936604";
		string s,log_file;                                                                            
		mobile=args[1];
		fee=(int)args[2];
		yushi_type=args[3];
		//��������ʶ����liaocheng��08/03/04��ӡ�
		string spec_fg = "0";
		if(sizeof(args)==5)
			spec_fg = args[4];
		string yushi_name = "������Ե��";
		switch(yushi_type){
			case "suiyu":
				yushi_level = 1;
				yushi_name = "��������";
				break;
			case "linglongyu":
				yushi_level = 3;
				yushi_name = "����������";
				break;
			case "biluanyu":
				yushi_level = 4;
				yushi_name = "���񡿱�����";
				break;
			case "xuantianbaoyu":
				yushi_level = 5;
				yushi_name = "�������챦��";
				break;
			default:
				yushi_name = "������Ե��";
		}
		object con=Stdio.File();
		con->connect(IP,PORT);
		con->write("login_fee "+PROJECT+" "+mobile+"\n");
		con->write("yushi_add_fee "+fee+" "+yushi_level+" "+spec_fg+"\n");

		int i,mon,day=0; 
		mapping now_time = localtime(time()); 
		mon = now_time["mon"]+1; 
		day = now_time["mday"]; 
		log_file = LOG +".log";                
		string now=ctime(time());
		s=mon+"-"+day+" ͳ������   \n  ʱ�䣺"+now[0..sizeof(now)-2]+"    �û���"+mobile+"    ����"+fee+"��"+yushi_name+"\n";
		Stdio.append_file(log_file,s);
		con->write("quit\n");
		con->close();

		write("�˺ţ�\n");
		write(mobile+"\n");
		write("������"+fee+"��"+yushi_name+"\n");
		write(fee+"\n");
	}
	else
	{
		write("��������\n");	
	}

	return 0;
}
