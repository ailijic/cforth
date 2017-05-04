#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <sys/mman.h>

extern int errno ;

int main () {
    const char str1[] = "string 1";
    char *anon;
    anon = (char*)mmap(NULL, 4096, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_ANON|MAP_SHARED, -1, 0);
    if (anon == MAP_FAILED) {
        return 1;
    }

    strcpy(anon, str1);

    // printf("val = %d \n", anon);
    puts(anon);

    /*
    void *mem;
    mem = mmap(
            0,
            4096,
            (PROT_EXEC | PROT_READ | PROT_WRITE),
            (MAP_PRIVATE | MAP_ANONYMOUS),
            -1,
            0
    );
    printf("val = %d", mem);
    */
/*
   FILE * pf;
   int errnum;
   pf = fopen ("unexist.txt", "rb");
	
   if (pf == NULL) {
   
      errnum = errno;
      fprintf(stderr, "Value of errno: %d\n", errno);
      perror("Error printed by perror");
      fprintf(stderr, "Error opening file: %s\n", strerror( errnum ));
   }
   else {
   
      fclose (pf);
   }
*/ 
   return 0;
}
