/*
 * This file is part of mplayer2.
 *
 * mplayer2 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * mplayer2 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with mplayer2; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#include <stdio.h>
#include "talloc.h"
#include "core/playlist.h"
#include "macosx_finder_args.h"
#include "osdep/macosx_application_objc.h"

static struct playlist *_files   = NULL;

static void handle_files_array(NSArray *files)
{
    if (files) {
        _files = talloc_zero(NULL, struct playlist);
        for (NSString *filename in files)
            playlist_add_file(_files, [filename UTF8String]);
    }
}

static void macosx_wait_fileopen_events()
{
    Application *app = [NSApp delegate];
    app.willStopOnOpenEvent = YES;
    cocoa_run_runloop(); // block until done
    handle_files_array(app.files);
}

static void macosx_redirect_output_to_logfile(const char *filename)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *log_path = [NSHomeDirectory() stringByAppendingPathComponent:
        [@"Library/Logs/" stringByAppendingFormat:@"%s.log", filename]];
    freopen([log_path fileSystemRepresentation], "a", stdout);
    freopen([log_path fileSystemRepresentation], "a", stderr);
    [pool release];
}



static bool psn_matches_current_process(char *psn_arg_to_check)
{
    ProcessSerialNumber psn;
    size_t psn_length = 5+10+1+10;
    char psn_arg[psn_length+1];

    GetCurrentProcess(&psn);
    snprintf(psn_arg, 5+10+1+10+1, "-psn_%u_%u",
             psn.highLongOfPSN, psn.lowLongOfPSN);
    psn_arg[psn_length]=0;

    return strcmp(psn_arg, psn_arg_to_check) == 0;
}

bool macosx_finder_args(m_config_t *config, struct playlist *pl_files,
                        int argc, char **argv)
{
    if (argc==1 && psn_matches_current_process(argv[0])) {
        macosx_redirect_output_to_logfile("mpv");
        m_config_set_option0(config, "quiet", NULL);
        macosx_wait_fileopen_events();
    }

    if (_files) {
        playlist_transfer_entries(pl_files, _files);
        talloc_free(_files);
        _files = NULL;
        return true;
    } else {
        return false;
    }
}

