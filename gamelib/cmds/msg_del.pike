#include <command.h>
#include <gamelib/include/gamelib.h>

//ɾ������

int main(string arg)
{
	int id = (int)arg;
	string s = "";
	if(MSGD->msg_del(id)==1){
		s += "ɾ���ɹ���\n";
		MSGD->write_file();
	}
	else {
		s += "�ù��治���ڣ�\n";
	}
	s += "\n";
	s += "[����:msg_read admin old]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
