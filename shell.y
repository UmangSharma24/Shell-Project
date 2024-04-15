
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [ | cmd [arg]* ]* [ [> filename] [< filename] [2> filename]
 *  [ >& filename] [>> filename] [>>&filename] ]* [&]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE GREATGREAT PIPE AMPERSAND LESS GREATAMPERSAND GREATGREATAMPERSAND TWOGREAT EXIT

%{  
//#define yylex yylex
#define MAXFILENAME 1024

#include <cstdio>
#include "shell.hh"
#include <string.h>
#include <cstring>
#include <sys/types.h>
#include <regex.h>
#include <dirent.h>
#include <stdlib.h>
#include <assert.h>
#include <unistd.h>

void yyerror(const char * s);
int yylex();
void expandWildCardsIfNecessary(std::string * arguments);
void expandWildCard(char* prefix, char* suffix);

int cstring_cmp(const void *a, const void *b);

int max_entries = 1024;
int nEntries = 0;
char **array = (char **) malloc(max_entries*sizeof(char *));

%}

%%

goal:
  command_list;
  ;

arg_list:
  arg_list WORD {
    //Command::_currentSimpleCommand->insertArgument( $2 );
    expandWildCardsIfNecessary($2);
  }
  | /* empty string */
  ;

cmd_and_args:
    /* EXIT {
      printf("Good bye!!\n");
      exit(1);
    } */
    
    WORD {
      Command::_currentSimpleCommand = new SimpleCommand();
      Command::_currentSimpleCommand->insertArgument( $1 );
      Command::_currentSimpleCommand->real_path = Shell::path;
    } arg_list
;

pipe_list:
  pipe_list PIPE cmd_and_args {
    Shell::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand );
  }
  | cmd_and_args {
    Shell::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

io_modifier:
  GREATGREAT WORD {
    if (Shell::_currentCommand._appendOut || Shell::_currentCommand._outFile) {
      Shell::_currentCommand.error_check = true;
    } else {
      Shell::_currentCommand._appendOut = true;
      Shell::_currentCommand._outFile = $2;
    }
  }
  | GREAT WORD {
    if (Shell::_currentCommand._outFile) {
      Shell::_currentCommand.error_check = true;
    }
    else {
      Shell::_currentCommand._outFile = $2;
    }
  }
  | TWOGREAT WORD {
    if (Shell::_currentCommand._appendErr) {
      Shell::_currentCommand.error_check = true;
    }
    else {
      Shell::_currentCommand._errFile = $2;
    }
  }
  | GREATGREATAMPERSAND WORD {
    if (Shell::_currentCommand._appendOut || Shell::_currentCommand._appendErr ||
         Shell::_currentCommand._outFile || Shell::_currentCommand._errFile) {
      Shell::_currentCommand.error_check = true;
    }
    else {
      Shell::_currentCommand._appendOut = true;
      Shell::_currentCommand._appendErr = true;
      Shell::_currentCommand._sameFilename = true;
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._errFile = $2;
    }
  }
  | GREATAMPERSAND WORD {
    if (Shell::_currentCommand._outFile || Shell::_currentCommand._errFile) {
      Shell::_currentCommand.error_check = true;
    }
    else {
      Shell::_currentCommand._sameFilename = true;
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._errFile = $2;
    }
  }
  | LESS WORD {
    if (Shell::_currentCommand._inFile) {
      Shell::_currentCommand.error_check = true;
    }
    else {
      Shell::_currentCommand._inFile = $2;
    }
  }
  ;

io_modifier_list:
  io_modifier_list io_modifier
  | /* empty */
  ;

background_optional:
  AMPERSAND {
    Shell::_currentCommand._background = true;
  }
  | /* empty */
  ;

command_line:
  pipe_list io_modifier_list background_optional NEWLINE {
    Shell::_currentCommand.execute();
  }
  | NEWLINE /* accept empty cmd line */
  | error NEWLINE{yyerrok;}
  ; /* error recovery */

command_list:
  command_line |
  command_list command_line
  ; /* command loop */

%%

void expandWildCardsIfNecessary(std::string * arguments) {
  
  //printf("%s", arguments[1].c_str());

  const char *arguments_c = arguments->c_str();
  if ((!strchr(arguments_c, '*') &&
        !strchr(arguments_c, '?')) |
        strcmp(arguments_c, "${?}") == 0) {

        Command::_currentSimpleCommand->insertArgument(arguments);
        return;
  }
  
  char *suffix_string = strndup(arguments_c, arguments->size());
  expandWildCard("", suffix_string);
  free(suffix_string);

  if (nEntries == 0) {
    Command::_currentSimpleCommand->insertArgument(arguments);
    return;
  }
  qsort(array, nEntries, sizeof(char *), cstring_cmp);

  for (int i = 0; i < nEntries; i++) {
    std::string *arg = new std::string(array[i]);
    memset(array[i], 0, sizeof(array[i]));
    Command::_currentSimpleCommand->insertArgument(arg);
  }
  nEntries = 0;
  return;
}

void expandWildCard(char* prefix, char* suffix) {

  //printf("Prefix: %s, Suffix: %s\n", prefix, suffix);

  if (suffix[0] == 0) {
    // suffix is empty. Put prefix in argument
    return;
  }
  // Obtain the next component in the suffix
  // Also advance suffix.
  char * s = strchr(suffix, '/');
  char component[MAXFILENAME];
  bool add = false;
  if (s != NULL){ 
    // Copy up to the first “/”
    //printf("s-suffix = %d\n", s-suffix);
    strncpy(component, suffix, s-suffix);
    component[s-suffix] = '\0';
    suffix = s + 1;
  }
  else { 
    // Last part of path. Copy whole thing.
    strcpy(component, suffix);
    suffix = suffix + strlen(suffix);
    add = true;
  }

  //printf("Component: %s\n", component);
  //printf("NewSuffix: %s\n", suffix);

  //Now we need to expand the component
  char newPrefix[MAXFILENAME];
  if (!strchr(component, '*') && !strchr(component, '?')) {
    // component does not have wildcardss
    
    if (prefix[strlen(prefix) - 1] == '/') {
      sprintf(newPrefix, "%s%s", prefix, component);
    }
    else {
      sprintf(newPrefix, "%s/%s", prefix, component);
    }

    //printf("NewPrefix: %s, suffix: %s\n", newPrefix, suffix);
    expandWildCard(newPrefix, suffix);
    return;
  }

  // Component has wildcards
  // Convert component to regular expression
  char *reg = (char*)malloc(2*strlen(component) + 10);
  char *a = component;
  char *r = reg;
  *r = '^';
  r++;
  // match beginning of line
  while (*a) {
    if (*a == '*') {
      *r = '.';
      r++;
      *r = '*';
      r++;
    }
    else if (*a == '?') {
      *r = '.';
      r++;
    }
    else if (*a == '.') {
      *r = '\\';
      r++;
      *r = '.';
      r++;
    }
    else if (*a == '/') {

    }
    else {
      *r = *a; 
      r++;
    }
    a++;
  }

  *r = '$'; 
  r++; 
  *r=0; 
  //match end of line and add null char

  regex_t re;

  int expbuf = regcomp(&re, reg, REG_EXTENDED | REG_NOSUB);
  //printf("Regex: %s\n", reg);
  if (expbuf != 0) {
    perror("compile");
    return;
  }
  
  char *dir;
  // If prefix is empty then list current directory
  if (prefix[0] == 0) { 
    dir = ".";
  } 
  else {
    dir = prefix;
  }

  //printf("Directory name: %s\n", dir);
  DIR * d = opendir(dir);
  if (d == NULL) { 
    return;
  }

  struct dirent *ent;
  regmatch_t match;

  //printf("%d\n", add);

  //Now we need to check what entries match
  while ((ent = readdir(d)) != NULL) {
    // Check if name matches
    if (regexec(&re, ent->d_name, 1, &match, 0) == 0) {
      // Entry matches. Add name of entry 
      // that matches to the prefix and
      // call expandWildcard(..) recursively

      if (ent->d_name[0] == '.') {
        if (component[0] == '.') {
          if (prefix[strlen(prefix) - 1] == '/') {
            sprintf(newPrefix, "%s%s", prefix, ent->d_name);
          }
          else {
            sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
          }
          if (add) {
            char *np = newPrefix;
            if (prefix[0] == 0) {
              np++;
            }
            array[nEntries] = strdup(np);
            nEntries++;
          }
        }
      }
      else {
        if (prefix[strlen(prefix) - 1] == '/') {
          sprintf(newPrefix, "%s%s", prefix, ent->d_name);
        }
        else {
          sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
        }
        if (add) {
          char *np = newPrefix;
          if (prefix[0] == 0) {
            //printf("Adding item from HOME directory\n");
            np++;
          }
          array[nEntries] = strdup(np);
          nEntries++;
        }
      }
      
      //printf("newPrefix: %s\n newSuffix: %s\n", newPrefix, suffix);
      expandWildCard(newPrefix, suffix);
    }
  }

  regfree(&re);
  closedir(d);
  free(reg);
}// expandWildcard

int cstring_cmp(const void *a, const void *b) {
  const char **ia = (const char **)a;
  const char **ib = (const char **)b;
  return strcmp(*ia, *ib);
}


void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

#if 0
main()
{
  yyparse();
}
#endif
