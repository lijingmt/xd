#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string slotName = arg;
	string s = "";
	s += HOMED->banner_slot(slotName);
	s += HOMED->query_flat_for_sale(slotName);
	s += "\n[∑µªÿ:home_purchase_slot_list "+ HOMED->query_area_by_slot(slotName) +"]\n";
	s += "[∑µªÿ”Œœ∑:look]\n"; 
	write(s);
	return 1;
}
