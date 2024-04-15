#include <cstdio>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <string.h>
#include <stdlib.h>

#include "shell.hh"

int yyparse(void);

void Shell::prompt() {
  if (isatty(0)) {
    printf("myshell>");
    fflush(stdout);
  }
}

extern "C" void sigIntHandler( int sig ) {
  //fprintf( stderr, "\nsig:%d      Ouch!\n", sig);
  Shell::prompt();
}

extern "C" void killzombie( int pidNumber ) {
  pidNumber = waitpid(-1, NULL, WNOHANG);
  while (pidNumber > 0) {
    pidNumber = waitpid(-1, NULL, WNOHANG);
  }
  //fprintf( stderr, "%d exited\n", pidNumber);
  //Shell::prompt();
}


int main(int argc, char** argv) {
  Shell::path = argv[0];

  Shell::prompt();

  //Implementing Ctrl-C functionality in the shell
  struct sigaction signalAction;
  signalAction.sa_handler = sigIntHandler;
  sigemptyset(&signalAction.sa_mask);
  signalAction.sa_flags = SA_RESTART;
  int error = sigaction(SIGINT, &signalAction, NULL);

  if (error) {
    perror("sigaction");
    //Shell::prompt();
    exit(-1);
  }

  //Implementing zombie process killer functionality in the shell
  struct sigaction signalActionZ;
  signalActionZ.sa_handler = killzombie;
  sigemptyset(&signalActionZ.sa_mask);
  signalActionZ.sa_flags = SA_RESTART;
  int error2 = sigaction(SIGCHLD, &signalActionZ, NULL);
  
  if (error2) {
    Shell::prompt();
    perror("sigaction");
    exit(-1);
  }


  yyparse();
}

Command Shell::_currentCommand;
std::string Shell::path;
