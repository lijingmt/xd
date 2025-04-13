  This document will show you how to create a new game of xiandII.

  (1) First of all,you should cut out a new copy of our project form SVN server.
        step 1:enter the folder which you would like to have your new game stored;
        strp 2:cut out what you want from the SVN server by using following command:
                  svn co svn://221.130.176.164/xiand2.0/trunk xiand*
        (tips:I think you are clever enough to know that 'xiand*' is the name of your new game,which means you can choose any name you like,I'd like take 'xiand*' for example there)

  If everything goes well,there should be a new folder named 'xiand*' in your path.
  (2) Then,enter the floder xiand*, you will find three more folders there,what you should do next is:
        step 1:enter the folder 'not_in_svn' (this folder includs those files and folders which are not controled by SVN)
        step 2:excute 'cp_file.sh'

  After your excutting of cp_file.sh, all the files and folders in "not_in_svn" had been copy to the place where they should be.
  (3) Now,you should modify some files to make your game differernt from others.
      There's a list of those files which you should modify:(take xiand* as the base root)
	Gruop A:
	  You should choose a Linux port for your game,then modify the following files:
	  * lowlib/system/include/globals.h  (all the globle parameters are definitioned here.So,PAY ATTENTION)
	  * callback_add.pike
	  * startup.sh
	  * lowlib/etc/hosts_list
        Group B:
	  In our game,if you post several parameters to the game server from a single page,we catch all of them by a single argument.So we have to devide it into sevreal parts by the command "sscanf()" to restore these parameters. But the command "sscanf()" doesn't always works well.In diffrent games,we got the parameters in different orders.No one knows why.Fortunatly,the command works so stability in the same game.So,you have to make sure that all your "sscanf()" works well.There is the list of those files which had use the damned command "sscanf()":
	  * gamelib/cmds/present_set.pike
	  * gamelib/cmds/fee_exchange_to_confirm.pike
	  * gamelib/cmds/bandpsw_change_confirm.pike
	  * gamelib/cmds/msg_write_confirm.pike
	  * gamelib/cmds/lottery_view_list.pike
	  * gamelib/cmds/vendue_confirm.pike
	  * gamelib/cmds/fee_exchange_list.pike

  (4) Now,it is time to deal with your datas.
      step 1:user files 
            After excute "cp_file.sh" ( in section(2) step 2 ),we bulid a new folder "udtestII",which is stored in the same level with "xiand*", modify its name to make it fit your new game.
            (Attention: the new name MUST be same to the definition of "DATA_ROOT" in lowlib/system/include/globals.h )
      strp 2:Databases
            You should create a new database for your game.This is so simple,Make sure your database have the same structure with all those databases in 221.130.176.131 whose name start with "xiand"
            (Attention: the name of your databases MUST be same to the definition of "DATABASE_NAME" in lowlib/system/include/globals.h )
           
  (5)Web application
     Every game has its web application,you can create your own web app by copying other game's app.then modify the file "config.inc" in th folder "inlcluds".
     Make sure your definition is fit with those defind in "lowlib/system/include/globals.h"

     OK, after doing all above,you have create a new game of xiandII.

	 【Evan 2009.01.07 at Dogstart】


Update on April 12 2025:

All front end codes are under the frontjsp folder, you can just copy them to yout tomcat/webapps/, then you are good to go.
frontjsp/xd/includes/config.inc this file is the key file you need to modify and configure your server ip here
we use 3rd party js package bootstrap
frontjsp/xd/images: all the initial game images are stored under this folder
main.jsp: this jsp will connect to backend server and generate the html back to frontend
pc.jsp: this is then entry point, generally users can login from this page
entrycheck.jsp is in charge of checking and validating the user password

Pike env setup:
The Stardard of version is 8.0, but you can use 7.8 as well.
you can setup on your macos, or your test linux centos, 8.0 support the most latest OS.


