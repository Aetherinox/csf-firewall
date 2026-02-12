/*
	# #
	#   @app                ConfigServer Security & Firewall (CSF)
	#                       Login Failure Daemon (LFD)
	#   @website            https://configserver.dev
	#   @docs               https://docs.configserver.dev
	#   @download           https://download.configserver.dev
	#   @repo               https://github.com/Aetherinox/csf-firewall
	#   @copyright          Copyright (C) 2025-2026 Aetherinox
	#                       Copyright (C) 2006-2025 Jonathan Michaelson
	#                       Copyright (C) 2006-2025 Way to the Web Ltd.
	#   @license            GPLv3
	#   @updated            02.12.2026
	#   
	#   This program is free software; you can redistribute it and/or modify
	#   it under the terms of the GNU General Public License as published by
	#   the Free Software Foundation; either version 3 of the License, or (at
	#   your option) any later version.
	#   
	#   This program is distributed in the hope that it will be useful, but
	#   WITHOUT ANY WARRANTY; without even the implied warranty of
	#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
	#   General Public License for more details.
	#   
	#   You should have received a copy of the GNU General Public License
	#   along with this program; if not, see <https://www.gnu.org/licenses>.
	# #
*/
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>
#include <pwd.h>
main ()
{
	FILE *adminFile;
	FILE *resellerFile;
	uid_t ruid;
	char name[100];
	struct passwd *pw;
	int admin = 0;
	int reseller = 0;

	setenv("CSF_RESELLER", "", 1);
	ruid = getuid();
	pw = getpwuid(ruid);

	adminFile=fopen ("/usr/local/directadmin/data/admin/admin.list","r");
	if (adminFile!=NULL)
	{
		while(fgets(name,100,adminFile) != NULL)
		{
			int end = strlen(name) - 1;
			if (end >= 0 && name[end] == '\n') name[end] = '\0';
			//printf("Name [%s]\n", name);
			if (strcmp(pw->pw_name, name) == 0) admin = 1;
		}
		fclose(adminFile);
	}
	if (admin == 1)
	{
		setuid(0);
		setgid(0);

		execv("/usr/local/directadmin/plugins/csf/exec/da_csf.cgi", NULL);
	} else {
		resellerFile=fopen ("/usr/local/directadmin/data/admin/reseller.list","r");
		if (resellerFile!=NULL)
		{
			while(fgets(name,100,resellerFile) != NULL)
			{
				int end = strlen(name) - 1;
				if (end >= 0 && name[end] == '\n') name[end] = '\0';
				//printf("Name [%s]\n", name);
				if (strcmp(pw->pw_name, name) == 0)
				{
					reseller = 1;
					setenv("CSF_RESELLER", pw->pw_name, 1);
				}
			}
			fclose(resellerFile);
		}
		if (reseller == 1)
		{
			setuid(0);
			setgid(0);

			execv("/usr/local/directadmin/plugins/csf/exec/da_csf_reseller.cgi", NULL);
		} else {
			printf("Permission denied [User:%s UID:%d]\n", pw->pw_name, ruid);
		}
	}

	return 0;
}
