#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string slotName = "";
	string flatName = "";
	sscanf(arg,"%s %s",slotName,flatName);
	string s = "";
	s += HOMED->banner_flat(slotName,flatName);
	s += HOMED->query_home_for_sale(slotName,flatName);
	s += "\n[∑µªÿ:home_purchase_flat_list "+ slotName +"]\n";
	s += "[∑µªÿ”Œœ∑:look]\n";
	write(s);
	return 1;
}
