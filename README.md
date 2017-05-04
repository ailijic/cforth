# cforth
A Forth interpreter written mostly in assembly; using C for some bootstrapping, e.g. OS system calls 

* See doc folder for links, notes, build log, etc.

To start we will be using
[FIRST & THIRD, almost FORTH](http://www.ioccc.org/1992/buzzard.2.design) (copy in docs)
I am also using [jonesForth](https://github.com/AlexandreAbreu/jonesforth) as a guide for the assembly routines. At the time of writing this (May 4, 2017) I could get the "jonesForth" project to compile but it would seg-fault when I tried to run it. To my untrained eye it looks like the code is directly making system calls and the interfaces have probaly changed.

### Motivation
The beauty of forth is that you can be very close to the hardware and very abstract at the same time. I am using a mix of C and assembly for this project. I want to get proficient with assembly and get a better idea of how programming languages and operating systems work. Assembly is a tool that every programmer should have in their tool box, but it should rarely be the first tool you reach for. I started in assembly and then decided to use C for the system calls. 

### Reasons for Using C
I started out and was successful in doing the system calls in assembly, I recommend trying it for the learning experience, but as I went on I realized I was creating a poor imitation of C. The more I wrote, and then refactored with constants and macros, the more it statred to look like C. Also, doing system calls in assembly means reading the `man` page documentation and then adding the extra step of finding the header file so you can lookup the values for flags, etc. Certain information can be hard to find, (see `/doc/links` file) things like writing to `stdout` are pretty standard, but maping memory pages seems to vary. After four, 12+ hour days of learning and coding assembly, C was like a shinning beacon of hope.

### Assembly: Lessons Learned
* AT&T or INTEL syntax?:
  * You have to be able to read both, and you need to know one well. I chose Intel syntax because:
    * Most of the guides and documentaion that I found was in Intel syntax.
    * Syntax errors are easier to spot in Intel syntax because you don't have to change the operand order.
    * Intel syntax matches very well with the bytecodes that the system uses. (Usefull if you want to do self modifying code)
    * Some of the new opcodes can take something like 4 or 5 operands which can be very tricky to reorder.
* Unlike C, assembly macros are your friend. 
* Constants are also your friend and give context to the seemingly arbitrary numbers you are pushing around.
* Seg-faults, seg-faults everywhere. You are going to dereference memory or forget to. This will crash your program, often. To the point where you might become convinced that the purpose of your program is to generate seg-faults. Which brings me to my next point.
* Have a good debugger. Printing to the console is not really an option. Personally I think it is a terible and inefficient way to debug. It makes me sad when a language does not have a good console based debugger and or the recommend way of debugging is print to the the console.


### Inital Reactions
I naively thought that 
