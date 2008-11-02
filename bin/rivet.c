#include <tcl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	Tcl_Interp *interp;
	char newpath_str[8192], parse_str[8192], execdir_str[8192], putenv_buf[8192];
	char linkinfo[8192], *tmp = NULL;
	char *scpfile = NULL, *pt_env = NULL, *pathinfo = NULL;
	char *path = NULL;
	size_t chklen;
	int chkval;
	long bytes_to_copy;
	CONST char *chkstr;
	CONST char *orig_errmsg, *err_errmsg;

	/*
	 * Verify we were called correctly.
	 */
	if (argc == 0) {
		fprintf(stderr, "Wrong number of arguments, aborting.\n");
		return(EXIT_FAILURE);
	}

	pt_env = getenv("PATH_TRANSLATED");
	if (pt_env) {
		scpfile = strdup(pt_env);
	}

	/*
	 * Create an interpreter or bail out.
	 */
	interp = Tcl_CreateInterp();
	if (!interp) {
		fprintf(stderr, "Could not create interpreter, aborting.\n");
		return(EXIT_FAILURE);
	}

	/*
	 * Perform standard Tcl initialization.
	 */
	chkval = Tcl_Init(interp);

	/*
	 * Update the "auto_path" variable
	 *   -- Determine the path to the package
	 *      -- Determine the path to ourselves
	 */
	execdir_str[0] = '\0';

	/*
	 * If no argv[0] is specified, give up trying to find ourselves.
	 */
	if (argv[0] == NULL) {
		fprintf(stderr, "Could not locate myself, aborting. (argv[0] = null)\n");
		return(EXIT_FAILURE);
	}

	/*
	 * Ensure we have enough buffer room to hold the value
	 */
	if (strlen(argv[0]) >= sizeof(execdir_str)) {
		fprintf(stderr, "Could not locate myself, aborting. (argv[0] too big)\n");
		return(EXIT_FAILURE);
	}

	/*
	 * Copy the value into our buffer
	 */
	strcpy(execdir_str, argv[0]);

#ifdef __WIN32__
	{
		char *p;
		p = execdir_str;

		while (*p) {
			if (*p == '\\') {
				*p = '/';
			}

			p++;
		}
	}
#endif

#ifdef LINUX
	/*
	 * Under Linux we can find ourselves via "/proc/PID/exe"
	 */
	snprintf(execdir_str, sizeof(execdir_str), "/proc/%i/exe", getpid());
	execdir_str[sizeof(execdir_str) - 1] = '\0';
#else
	/*
	 * If there was no path delimiters in the passed argv[0] assume
	 * the executable can be found in the path.
	 */
	tmp = strrchr(execdir_str, '/');
	if (!tmp) {
		path = getenv("PATH");
		if (path) {
			path = strdup(path);
		}

		if (path) {
			for (tmp = strtok(path, ":"); tmp; tmp = strtok(NULL, ":")) {
				chklen = snprintf(execdir_str, sizeof(execdir_str), "%s/%s", tmp, argv[0]);
				if (chklen >= sizeof(execdir_str)) {
					execdir_str[0] = '\0';
					continue;
				}

				if (access(execdir_str, X_OK) == 0) {
					break;
				}

				execdir_str[0] = '\0';
			}
		}
	}
#endif

	if (execdir_str[0] == '\0') {
		fprintf(stderr, "Could not locate myself, aborting. (failed to perform)\n");
		return(EXIT_FAILURE);
	}

	if (access(execdir_str, X_OK) != 0) {
		fprintf(stderr, "Could not locate myself, aborting. (not executable)\n");
		return(EXIT_FAILURE);
	}

	/*
	 * Resolve all symlinks whose target is the executable itself.
	 */
	while (1) {
#ifndef __WIN32__
		chkval = readlink(execdir_str, linkinfo, sizeof(linkinfo));
#else
		chkval = -1;
#endif

		if (chkval == -1) {
			break;
		}

		if ((size_t) chkval >= sizeof(linkinfo)) {
			fprintf(stderr, "Could not locate myself, aborting. (linkname too big)\n");
			return(EXIT_FAILURE);
		}

		linkinfo[chkval] = '\0';

		tmp = strrchr(execdir_str, '/');
		if (tmp && linkinfo[0] != '/') {
			tmp++;
			*tmp = '\0';
			bytes_to_copy = sizeof(execdir_str) - strlen(execdir_str) - 1;

			if (bytes_to_copy <= 0) {
				fprintf(stderr, "Could not locate myself, aborting. (no bytes to copy)\n");
				return(EXIT_FAILURE);
			}

			strncat(execdir_str, linkinfo, bytes_to_copy);
		} else {
			strcpy(execdir_str, linkinfo);
		}
	}

	/*
	 * Ensure that this target is real, and executable.
	 */
	if (access(execdir_str, X_OK) != 0) {
		fprintf(stderr, "Could not locate myself, aborting. (no access to execdir=\"%s\")\n", execdir_str);
		return(EXIT_FAILURE);
	}

	/*
	 * Now that we have resolved the symbolic links, remove the filename.
	 */
	tmp = strrchr(execdir_str, '/');
	if (tmp) {
		*tmp = '\0';
	}

	/*
	 *   -- Construct the path to the package
	 */
	chklen = snprintf(newpath_str, sizeof(newpath_str), "%s/../packages/tclrivet/", execdir_str);
	if (chklen >= sizeof(newpath_str)) {
		fprintf(stderr, "Could not construct pathname, aborting.\n");
		return(EXIT_FAILURE);
	}

	/*
	 *   -- Update the "auto_path" variable
	 */
	chkstr = Tcl_SetVar(interp, "auto_path", newpath_str, TCL_APPEND_VALUE | TCL_LIST_ELEMENT);
	if (chkstr == NULL) {
		fprintf(stderr, "Could update auto_path, aborting.\n");
		return(EXIT_FAILURE);
	}

	/*
	 * Free allocated memory.
	 */
	if (path) {
		free(path);
	}

	/*
	 * Load the "tclrivet" package
	 */
	chkval = Tcl_Eval(interp, "package require tclrivet");
	if (chkval != TCL_OK) {
		fprintf(stderr, "Could not evaluate package command, aborting.\n");
		return(EXIT_FAILURE);
	}

	/*
	 * Ensure that the script file is properly defined and accessible.
	 */
	/*
	 *   -- Verify that the scpfile has even been defined
	 */
	if (scpfile == NULL) {
		fprintf(stderr, "Could not determine executable script, aborting.\n");
		return(EXIT_FAILURE);
	}

	/*
	 *   -- If the "scpfile" doesn't exist, see if it's being MultiView'd/PATH_INFO processed
	 */
	pathinfo = strdup(scpfile);
	tmp = NULL;
	while (access(scpfile, F_OK) != 0) {
		tmp = strrchr(scpfile, '/');
		if (!tmp) {
			break;
		}
		*tmp = '\0';
	}
	if (tmp) {
		if (tmp > scpfile) {
			pathinfo += tmp - scpfile;
			snprintf(putenv_buf, sizeof(putenv_buf), "PATH_INFO=%s", pathinfo);
			putenv_buf[sizeof(putenv_buf) - 1] = '\0';
			putenv(putenv_buf);
		}
	}

	if (access(scpfile, F_OK) != 0 || strlen(scpfile) < 2) {
		fprintf(stderr, "Could not access executable script, aborting. (scp=\"%s\")\n", scpfile);
		return(EXIT_FAILURE);
	}

	/*
	 * Change directories to the script root
	 */
	path = strdup(scpfile);
	if (path) {
		tmp = strrchr(path, '/');
		if (tmp) {
			*tmp = '\0';

			chdir(path);
		}

		free(path);
	}

	/*
	 * Hand off execution to the script passed in scpfile
	 *    -- Construct the command string
	 */
	chklen = snprintf(parse_str, sizeof(parse_str), "parse \"%s\"", scpfile);
	if (chklen >= sizeof(parse_str)) {
		fprintf(stderr, "Could not construct parse command, aborting.\n");
		return(EXIT_FAILURE);
	}

	/*
	 *    -- Evaluate the command string
	 */
	chkval = Tcl_Eval(interp, parse_str);
	if (chkval != TCL_OK) {
		orig_errmsg = Tcl_GetVar(interp, "errorInfo", TCL_GLOBAL_ONLY);
		if (orig_errmsg) {
			orig_errmsg = strdup(orig_errmsg);
		}

		/*
		 * Attempt to generate an error page.
		 */
		chkval = Tcl_Eval(interp, "rivet_error");
		if (chkval != TCL_OK) {
			fprintf(stderr, "Error evaluating parse command: %s\n", orig_errmsg);
			err_errmsg = Tcl_GetVar(interp, "errorInfo", TCL_GLOBAL_ONLY);
			fprintf(stderr, "Additionally, an error occured while generating the error page: %s\n", err_errmsg);
		}

		return(EXIT_FAILURE);
	}

	/*
	 * Call "rivet_flush" and ignore any errors.
	 */
	Tcl_Eval(interp, "rivet_flush");

	/*
	 * Done
	 */
	return(EXIT_SUCCESS);
}
