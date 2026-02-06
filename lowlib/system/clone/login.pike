#include <globals.h>
#ifdef __INTERACTIVE_CATCH_TELL__
void catch_tell(string str) {
    receive(str);
}
#endif
void logon()
{
    object user;
    user= new(LOW_USER_OB);
    user->set_name("LoginTmp" + getoid(user));
    user->setup();
    exec(user, this_object());
#ifndef __NO_ENVIRONMENT__
    user->move(LOW_VOID_OB);
#endif
    destruct(this_object());
}
