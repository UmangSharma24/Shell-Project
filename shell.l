
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include "y.tab.hh"
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <pwd.h>

extern "C++" char * read_line();

int mygetc(FILE * f) {
  static char *p;
  char ch;

     if (!isatty(0)) {
  //stdin is not a tty. Call real getc
    return getc(f);
  }

  //stdin is a tty. Call our read_line.
  if (p==NULL || *p == 0) {
    char * s = read_line();
    p = s;
  }

  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

void buffer_set(FILE *file_pointer) {
  YY_BUFFER_STATE buffer = yy_create_buffer( file_pointer, YY_BUF_SIZE );
  yypush_buffer_state(buffer);
  yyparse();
  yypop_buffer_state();
}


%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">" {
  return GREAT;
}

">>" {
  return GREATGREAT;
}

"|" {
  return PIPE;
}

"&" {
  return AMPERSAND;
}

"<" {
  return LESS;
}

">&" {
  return GREATAMPERSAND;
}

">>&" {
  return GREATGREATAMPERSAND;
}

"2>" {
  return TWOGREAT;
}

"exit\n" {
  if (isatty(0)) {
    printf("Good bye!!\n");
  }
  exit(1);
  return EXIT;
}

~[a-zA-Z0-9_/]* {
  /* Implementing Tilde Functionality */

  std::string input = strdup(yytext);
  if (input.size() == 1) {
    input = "";
    input += getenv("HOME");
  }
  else {
    std::string buffer1;
    std::string buffer2 = "";
    int loc = input.find("/");
    if (loc < 0) {
      buffer1 = input.substr(1, input.size() - 1); 
    }
    else {
      buffer1 = input.substr(1, loc - 1);
      buffer2 = input.substr(loc + 1, input.size() - loc);
    }
    input = "";
    input += getpwnam(buffer1.c_str())->pw_dir;

    if (buffer2.size() > 0) {
      input += "/";
      input += buffer2;
    }
  }

  yylval.cpp_string = new std::string(input);
  return WORD;
}

\"[^\t\n\"]*\" {
  /*Implementing Quotes Functionality */
  char* buffer = strdup(yytext);

  char modified[strlen(buffer) - 1];
  int modifiedLen = strlen(buffer) - 2;

  for (int i = 0; i < modifiedLen; i++) {
    modified[i] = buffer[i + 1];
  }
  modified[modifiedLen] = '\0';

  yylval.cpp_string = new std::string(modified);
  return WORD;
}

"source "[^ \t\n\|\<\>\&\\]* {
  /* Implementing Source functionality */
  FILE *file_pointer = yyin;
  std::string input_buffer = strdup(yytext);
  /* Starting from index 7 to remove the "source " from the input */
  std::string filename = input_buffer.substr(7, input_buffer.size() - 7);
  yyin = fopen(filename.c_str(), "r");
  buffer_set(yyin);
}

[^ \t\n\&\|\"\$<>]*[\\][^ \n]* {
  /* Implementing Escape Character Functionality */
  char* buffer = strdup(yytext);
  int index = 0;
  int length = strlen(yytext);
  char result[length + 1];

  while (*buffer) {

    /* Checking char in buffer against ASCII value of \\ */
    if ((int) (*buffer) == 92) {
      buffer++;
      result[index] = *buffer;
      index++;
    }
    else {
      result[index] = *buffer;
      index++;
    }
    buffer++;
  }

  result[index] = '\0';
  yylval.cpp_string = new std::string(result);
  return WORD;
}

$\([^\n]*\)|\`[^\n]*\` {

  /* Implementing Subshell Functionality */

  std::string buffer = std::string(yytext);

  /* Incrementing buffer ptr by 2 to get rid of $( */
  if (buffer.at(0) == '$') {
    //remove $
    buffer = (buffer.substr(1, buffer.size() - 1));
  }
  buffer = (buffer.substr(1, buffer.size() - 2));
    
  int pin[2], pout[2];
  int tmpin = dup(0);
  int tmpout = dup(1);
  int tmperr = dup(2);

  pipe(pin);
  pipe(pout);

  write(pin[1], buffer.c_str(), buffer.size());
  write(pin[1], "\n", 1);
  write(pin[1], "exit\n", 5);
  close(pin[1]);

  dup2(pin[0], 0);
  dup2(pout[1], 1);
  close(pin[0]);
  close(pout[1]);

  int ret = fork();
  if (ret == 0) {
    char** args = new char*[2];
    args[0] = (char *) "/proc/self/exe";
    args[1] = NULL;
    execvp(args[0], args);    
  }

  dup2(tmpin, 0);
  dup2(tmpout, 1);
  close(tmpin);
  close(tmpout);

  char c;
  std::string temp_command = "";

  int read_check = read(pout[0], &c, 1);
  while (read_check) {
    if (c == '\n') {
      c = '\t';
    }
    temp_command += c;
    read_check = read(pout[0], &c, 1);
  }

  for (int i = temp_command.size() - 1; i >= 0; i--) {
    myunputc(temp_command.at(i));
  }
}

[^ \t\n\|\&\<\>\\][^ \t\n\|\&\<\>\\]* {

  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
} 

