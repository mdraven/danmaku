

===========================================================

Danmakufu вычислятор

Проблема в том что разных скриптов, в котором есть @BlaBla элементы,
  очень много: этажа, монстров итд
А ещё есть разные версии самого скрипта.

TODO: надо узнать, общее пространство имён(например объявленые функции) у разных скриптов
  или одно.


@o danmakufu.h @{
@<License@>

#include "dlist.h"

@<danmakufu.h structs@>
@<danmakufu.h prototypes@>
@}

@o danmakufu.c @{
@<License@>

#include "danmakufu.h"
#include "danmakufu_bytecode.h"

@<danmakufu.c structs@>
@<danmakufu.c prototypes@>
@<danmakufu.c functions@>
@}


Структура машины исполняющий байткод или native-код danmakufu:
@d danmakufu.h structs @{
struct DanmakufuMachine {
    int type;
    intptr_t *code;
    int code_size;

    DanmakufuTask *tasks;
    DanmakufuTask *last_task;

    DanmakufuDict *global;
};

typedef struct DanmakufuMachine DanmakufuMachine;
@}
По сути DanmakufuMachine -- это script_xxx + макросы в заголовке
type - тип кода(bytecode, native)
code - байткод(похож на forth)
code_size - размер байткода
tasks - указатель на список задач; last_task - последняя задача в списке,
  чтобы легче было вставлять первую в конец.
global - словарь слов-символов forth-машины(содержит переменные, имена функций итд)
  TODO: *global[32] - как насчёт хеширования?

Типы кода:
@d danmakufu.h structs @{
enum {
    danmakufu_bytecode,
    danmakufu_i386,
};
@}

Задача:
@d danmakufu.h structs @{
#define DANMAKUFU_TASK_STACK_SIZE 50
#define DANMAKUFU_TASK_RSTACK_SIZE 50
struct DanmakufuTask {
    struct DanmakufuTask *next;

    int ip;
    DanmakufuDictList *local;

    void *stack[DANMAKUFU_TASK_STACK_SIZE];
    int sp;

    void *rstack[DANMAKUFU_TASK_RSTACK_SIZE];
    int rp;
};

typedef DanmakufuTask DanmakufuTask;
@}
next - указатель на следующую задачу
ip - место выполнения процесса
local - указатель на список локальных словарей задачи(определения могут перекрываться);
  используется в качестве скопа
stack - указывает на элементы из ast(например: ast_string или ast_number)
sp - позиция в стеке
rstack - стек адресов возврата
rp - позиция в стеке


Словарь:
@d danmakufu.h structs @{
DLIST_DEFSTRUCT(DanmakufuDict)
    AstSymbol *symb;
    void *ptr;
DLIST_ENDS(DanmakufuDict)
@}
symb, ptr - символ и его значение.

Список занятых, свободных и удалённых элементов:
@d danmakufu.c structs @{
DLIST_SPECIAL_VARS(danmakufu_dicts, DanmakufuDict)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d danmakufu.c structs @{
DLIST_ALLOC_VARS(danmakufu_dicts, 1000, 100)
@}
по-идее должно совпадать с теми же параметрами для AstSymbol

Функция для возвращения выделенных слотов обратно в пул:
@d danmakufu.c functions @{
DLIST_FREE_FUNC(danmakufu_dicts, DanmakufuDict)
DLIST_END_FREE_FUNC(danmakufu_dicts, DanmakufuDict)
@}
возможно сюда стоит вставить код освобождения содержимого ptr.

Соединить danmakufu_dicts_pool_free с danmakufu_dicts_pool:
@d danmakufu.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(danmakufu_dicts, DanmakufuDict)
@}

danmakufu_dicts_get_free_cell - функция возвращающая свободный дескриптор:
@d danmakufu.c functions @{
DLIST_GET_FREE_CELL_FUNC(danmakufu_dicts, DanmakufuDict)
@}




Список словарей:
@d danmakufu.h structs @{
DLIST_DEFSTRUCT(DanmakufuDictList)
    DanmakufuDict *dict;
DLIST_ENDS(DanmakufuDictList)
@}


Список занятых, свободных и удалённых элементов:
@d danmakufu.c structs @{
DLIST_SPECIAL_VARS(danmakufu_dict_lists, DanmakufuDictList)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d danmakufu.c structs @{
DLIST_ALLOC_VARS(danmakufu_dict_lists, 100, 20)
@}



Функция загрузки скрипта:
@d danmakufu.h prototypes @{
DanmakufuMachine *danmakufu_load_file(const char *filename);
@}

@d danmakufu.c functions @{
DanmakufuMachine *danmakufu_load_file(const char *filename) {
    AstCons *cons = danmakufu_parse(filename);
    if(cons == NULL) {
        fprintf(stderr, "\ndanmakufu_parse error\n");
        exit(1);
    }

    DanmakufuMachine *mach = malloc(sizeof(DanmakufuMachine));
    if(mach == NULL) {
        fprintf(stderr, "\nCan't allocate memory for danmakufu_machine\n");
        exit(1);
    }

    mach->type = danmakufu_bytecode;
    mach->code = danmakufu_compile_to_bytecode(cons, &mach->code_size);

    return mach;
}
@}
TODO: написать обработку ошибок при парсинге скрипта

