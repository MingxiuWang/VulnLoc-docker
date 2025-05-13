/* **********************************************************
 * Copyright (c) 2014-2018 Google, Inc.  All rights reserved.
 * **********************************************************/

/*
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * * Neither the name of VMware, Inc. nor the names of its contributors may be
 *   used to endorse or promote products derived from this software without
 *   specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL VMWARE, INC. OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */

/* Code Manipulation API Sample:
 * cbrtrace.c
 *
 * Collects the conditional branch address, fall-through address,
 * target address, and taken information.
 * Writes that info into per-thread files named cbrtrace.<pid>.<tid>.log
 * in the client library directory.
 *
 * Illustrates how to use dr_insert_cbr_instrument_ex().
 */

#include "dr_api.h"
#include "drmgr.h"
#include "drutil.h"


#include <map>
#include <string>
#include <stdio.h>
#include <stdio.h>
#include <sstream>

using namespace std;

#define SIZE 10000;

map<long, int> addressMap;
long addresses[10000];

int findLine(int id) {
    printf("Client id %d\n", id);
    FILE *fp;

    stringstream stream;
    stream << hex << id;
    string result = "./tempDr/m"+stream.str()+".out";
    printf("file : %s\n", result.c_str());
    fp = fopen(result.c_str(), "rb");
	char buf[100];
	int i = 0;

    /*
        Take the input from the file 
        and convert them into numbers
        and then store them into map.
    */
	
	while(fgets(buf, sizeof(buf), fp) != NULL){
		int b;
		string a;
		sscanf(buf, "%s %d", a.c_str(), &b);
		// printf("%s %d %d\n", a.c_str(), b, c);
        addresses[i] = atol(a.c_str());
        // printf("%ld\n", addresses[i]);
		addressMap[addresses[i]] = b;
		i+=1;
	}

}


static client_id_t client_id;

static int tls_idx;

/* Clean call for the cbr */
static void
at_cbr(app_pc inst_addr, app_pc targ_addr, app_pc fall_addr, int taken, void *bb_addr)
{
    void *drcontext = dr_get_current_drcontext();

    // file_t log = (file_t)(ptr_uint_t)drmgr_get_tls_field(drcontext, tls_idx);
    long b = (long)(inst_addr);
    // string a(reinterpret_cast< char const* >(inst_addr));
    // dr_printf(PFX " %ld\n", inst_addr, b);
    int item = -1;
   
    if (addressMap.find(b) != addressMap.end()){
   	  	item = (addressMap.find(b))->second;
    }

    if(item != NULL && item != -1) {
      	dr_printf(PFX " => " "%d %d\n", 
      	inst_addr, item, taken == 0 ? 1:0);
    } 

}

static dr_emit_flags_t
event_app_instruction(void *drcontext, void *tag, instrlist_t *bb, instr_t *instr,
                      bool for_trace, bool translating, void *user_data)
{
    if (instr_is_cbr(instr)) {
        dr_insert_cbr_instrumentation_ex(drcontext, bb, instr, (void *)at_cbr,
                                         OPND_CREATE_INTPTR(dr_fragment_app_pc(tag)));
    }
    return DR_EMIT_DEFAULT;
}

// static void
// event_thread_init(void *drcontext)
// {
//     file_t log;
//     log =
//         log_file_open(client_id, drcontext, NULL /* using client lib path */, "cbrtrace",
// #ifndef WINDOWS
//                       DR_FILE_CLOSE_ON_FORK |
// #endif
//                           DR_FILE_ALLOW_LARGE);
//     DR_ASSERT(log != INVALID_FILE);
//     drmgr_set_tls_field(drcontext, tls_idx, (void *)(ptr_uint_t)log);
// }

// static void
// event_thread_exit(void *drcontext)
// {
//     log_file_close((file_t)(ptr_uint_t)drmgr_get_tls_field(drcontext, tls_idx));
// }

static void
event_exit(void)
{
    dr_log(NULL, DR_LOG_ALL, 1, "Client 'cbrtrace' exiting");
#ifdef SHOW_RESULTS
    if (dr_is_notify_on())
        dr_fprintf(STDERR, "Client 'cbrtrace' exiting\n");
#endif
    if (!drmgr_unregister_bb_insertion_event(event_app_instruction) ||
        !drmgr_unregister_tls_field(tls_idx))
        DR_ASSERT(false);
    drmgr_exit();
}

DR_EXPORT
void
dr_client_main(client_id_t id, int argc, const char *argv[])
{
    dr_set_client_name("DynamoRIO Sample Client 'acbrtrace'",
                       "http://dynamorio.org/issues");
    dr_log(NULL, DR_LOG_ALL, 1, "Client 'acbrtrace' initializing");

    drmgr_init();
    findLine(id);
    client_id = id;
    tls_idx = drmgr_register_tls_field();

    dr_register_exit_event(event_exit);
    if (
        !drmgr_register_bb_instrumentation_event(NULL, event_app_instruction, NULL))
        DR_ASSERT(false);

#ifdef SHOW_RESULTS
    if (dr_is_notify_on()) {
#    ifdef WINDOWS
        dr_enable_console_printing();
#    endif /* WINDOWS */
        dr_fprintf(STDERR, "Client 'acbrtrace' is running\n");
    }
#endif /* SHOW_RESULTS */
}
