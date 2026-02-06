#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	this_player()->clean_mail_box_all();
	this_player()->write_view_tmp(WAP_VIEWD["/delete_all_mail"]);
	return 1;
}


