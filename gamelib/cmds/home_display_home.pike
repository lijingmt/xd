#include <command.h>
#include <gamelib/include/gamelib.h>
//չʾflat�����е�home
int main(string arg)
{
	object me = this_player();
	string slotName = "";
	string flatName = "";
	int backFlag = 0;
	sscanf(arg,"%s %s %d",slotName,flatName,backFlag);
	string s = "";
	s += HOMED->banner_flat(slotName,flatName);
	s += HOMED->display_homes(slotName,flatName,backFlag);
	string slotPath = HOMED->query_slotPath(slotName);
	s += "\n[�뿪�ĺ�Ժ:qge74hye "+ slotPath + "]\n";
	write(s);
	return 1;
}
