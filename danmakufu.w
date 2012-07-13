

===========================================================

Danmakufu вычислятор

Проблема в том что разных скриптов, в котором есть @BlaBla элементы,
  очень много: этажа, монстров итд
А ещё есть разные версии самого скрипта.

TODO: надо узнать, общее пространство имён(например объявленые функции) у разных скриптов
  или одно.


@o danmakufu.h @{
@<License@>
#include <stdint.h>

#include "dlist.h"
#include "ast.h"

@<danmakufu.h structs@>
@<danmakufu.h prototypes@>
@}

@o danmakufu.c @{
@<License@>

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include "danmakufu.h"
#include "danmakufu_bytecode.h"
#include "danmakufu_parser.h"

@<danmakufu.c structs@>
@<danmakufu.c prototypes@>
@<danmakufu.c functions@>
@}


Типы кода:
@d danmakufu.h structs @{
enum {
    danmakufu_bytecode,
    danmakufu_i386,
};
@}


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
DLIST_ALLOC_VARS(danmakufu_dicts, 0xdead, 100)
@}
по-идее должно совпадать с теми же параметрами для AstSymbol


Функция для возвращения выделенных слотов обратно в пул:
@d danmakufu.c functions @{
DLIST_LOCAL_FREE_FUNC(danmakufu_dicts, DanmakufuDict)
DLIST_LOCAL_END_FREE_FUNC(danmakufu_dicts, DanmakufuDict)
@}
TODO:возможно сюда стоит вставить код освобождения содержимого ptr.

Соединить danmakufu_dicts_pool_free с danmakufu_dicts_pool:
@d danmakufu.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(danmakufu_dicts, DanmakufuDict)
@}

danmakufu_dicts_get_free_cell - функция возвращающая свободный дескриптор:
@d danmakufu.c functions @{
DLIST_LOCAL_GET_FREE_CELL_FUNC(danmakufu_dicts, DanmakufuDict)
@}

@d danmakufu.c functions @{
static DanmakufuDict *danmakufu_dict_create(DanmakufuDict *dict,
                                            AstSymbol *symb) {
    dict = danmakufu_dicts_get_free_cell(dict);

    dict->symb = symb;
    dict->ptr = NULL;

    return dict;
}
@}


@d danmakufu.c functions @{
static DanmakufuDict *danmakufu_dict_find_symbol(DanmakufuDict *dict,
                                                 const AstSymbol *symb) {
    DanmakufuDict *d;

    for(d = dict; d != NULL; d = d->next)
        if(d->symb == symb)
            return d;

    return NULL;
}
@}

@d danmakufu.c functions @{
static DanmakufuDict *copy_dict(DanmakufuDict *from) {
    DanmakufuDict *d;
    DanmakufuDict *new = NULL;

    for(d = from; d != NULL; d = d->next) {
        new = danmakufu_dict_create(new, d->symb);
        new->ptr = ast_copy_obj(d->ptr);
    }

    return new;
}
@}
символ копировать не надо так как он уже заинтернен

@d danmakufu.c functions @{
static DanmakufuDict *intern_to_dict(DanmakufuDict **head, AstSymbol *symb) {
    DanmakufuDict *dict;

    dict = danmakufu_dict_find_symbol(*head, symb);
    if(dict == NULL) {
         dict = danmakufu_dict_create(*head, symb);
         *head = dict;
    }

    return dict;
}
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
DLIST_ALLOC_VARS(danmakufu_dict_lists, 0xdead, 20)
@}

Функция для возвращения выделенных словарей обратно в пул:
@d danmakufu.c functions @{
DLIST_LOCAL_FREE_FUNC(danmakufu_dict_lists, DanmakufuDictList)
    if(elm == NULL)
        return;

    if(elm->dict) {
        DanmakufuDict *p;
        for(p = elm->dict->next; p != NULL; p = elm->dict->next)
            danmakufu_dicts_free(p);
        for(p = elm->dict->prev; p != NULL; p = elm->dict->prev)
            danmakufu_dicts_free(p);
        danmakufu_dicts_free(elm->dict);

        danmakufu_dicts_pool_free_to_pool();
        elm->dict = NULL;
    }
DLIST_LOCAL_END_FREE_FUNC(danmakufu_dict_lists, DanmakufuDictList)
@}

Соединить danmakufu_dict_lists_pool_free с danmakufu_dict_lists_pool:
@d danmakufu.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(danmakufu_dict_lists, DanmakufuDictList)
@}

danmakufu_dict_lists_get_free_cell - функция возвращающая свободный дескриптор:
@d danmakufu.c functions @{
DLIST_LOCAL_GET_FREE_CELL_FUNC(danmakufu_dict_lists, DanmakufuDictList)
@}

@d danmakufu.c functions @{
static DanmakufuDictList *danmakufu_dict_list_create(DanmakufuDictList *dict_list) {
    dict_list = danmakufu_dict_lists_get_free_cell(dict_list);

    dict_list->dict = NULL;

    return dict_list;
}
@}


@d danmakufu.c functions @{
static DanmakufuDict *danmakufu_dict_list_find_symbol(DanmakufuDictList *dict_list,
                                                      const AstSymbol *symb) {
    DanmakufuDictList *d;

    for(d = dict_list; d != NULL; d = d->next) {
        DanmakufuDict *t = danmakufu_dict_find_symbol(d->dict, symb);
        if(t)
            return t;
    }

    return NULL;
}
@}


Удалить все элементы из списка:
@d danmakufu.c functions @{
static void danmakufu_dict_list_clear(DanmakufuDictList *dict_list) {
    if(dict_list == NULL)
        return;

    DanmakufuDictList *p;
    for(p = dict_list->next; p != NULL; p = dict_list->next)
        danmakufu_dict_lists_free(p);
    for(p = dict_list->prev; p != NULL; p = dict_list->prev)
        danmakufu_dict_lists_free(p);
    danmakufu_dict_lists_free(dict_list);

    danmakufu_dict_lists_pool_free_to_pool();
}
@}

@d danmakufu.c functions @{
static DanmakufuDictList *copy_dict_list(DanmakufuDictList *from) {
    DanmakufuDictList *d;
    DanmakufuDictList *new = NULL;

    for(d = from; d != NULL; d = d->next) {
        new = danmakufu_dict_list_create(new);
        new->dict = copy_dict(d->dict);
    }

    return new;
}
@}


Задача:
@d danmakufu.h structs @{
#define DANMAKUFU_TASK_STACK_SIZE 50
#define DANMAKUFU_TASK_RSTACK_SIZE 50

DLIST_DEFSTRUCT(DanmakufuTask)
    int ip;
    DanmakufuDictList *local;

    void *stack[DANMAKUFU_TASK_STACK_SIZE];
    int sp;

    int rstack[DANMAKUFU_TASK_RSTACK_SIZE];
    int rp;
DLIST_ENDS(DanmakufuTask)
@}
next - указатель на следующую задачу
ip - место выполнения процесса
local - указатель на список локальных словарей задачи(определения могут перекрываться);
  используется в качестве скопа
stack - указывает на элементы из ast(например: ast_string или ast_number).
  Его можно сделать циклическим. Это позволит не заботится о функциях, которые что-то возвращают,
  и не дропать стек. Другой вариант(более эффективный): во время генерации байткода заполнять стек
  и использовать команду bc_stack. Те эмулировать регистры.
sp - позиция в стеке
rstack - стек адресов возврата
rp - позиция в стеке

Список занятых, свободных и удалённых элементов:
@d danmakufu.c structs @{
DLIST_SPECIAL_VARS(danmakufu_tasks, DanmakufuTask)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d danmakufu.c structs @{
DLIST_ALLOC_VARS(danmakufu_tasks, 0xdead, 10)
@}
по-идее должно совпадать с теми же параметрами для AstSymbol


Функция для возвращения выделенных слотов обратно в пул:
@d danmakufu.c functions @{
DLIST_LOCAL_FREE_FUNC(danmakufu_tasks, DanmakufuTask)
    if(elm == NULL)
        return;

    danmakufu_dict_list_clear(elm->local);
DLIST_LOCAL_END_FREE_FUNC(danmakufu_tasks, DanmakufuTask)
@}
возможно сюда стоит вставить код освобождения содержимого ptr.

Соединить danmakufu_tasks_pool_free с danmakufu_tasks_pool:
@d danmakufu.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(danmakufu_tasks, DanmakufuTask)
@}

danmakufu_tasks_get_free_cell - функция возвращающая свободный дескриптор:
@d danmakufu.c functions @{
DLIST_LOCAL_GET_FREE_CELL_FUNC(danmakufu_tasks, DanmakufuTask)
@}


@d danmakufu.c functions @{
static DanmakufuTask *danmakufu_create_new_task(DanmakufuTask *next_task) {
    DanmakufuTask *task = danmakufu_tasks_get_free_cell(next_task);
    if(task == NULL) {
        fprintf(stderr, "\nCan't allocate memory for danmakufu_task\n");
        exit(1);
    }

    task->ip = 0;
    task->local = danmakufu_dict_list_create(NULL);
    task->sp = 0;
    task->rp = 0;

    return task;
}
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

Функции для danmakufu script версии 2:
@d danmakufu.c functions @{
@<danmakufu.c danmakufu v2 functions@>@}

@d danmakufu.c functions @{
static void add_danmakufu_v2_funcs_to_dict(DanmakufuDict **dict) {
    DanmakufuDict *t;
    @<add_danmakufu_v2_funcs_to_dict functions@>
}
@}

Нестандартные функции для danmakufu:
@d danmakufu.c functions @{
@<danmakufu.c danmakufu my functions@>@}

@d danmakufu.c functions @{
static void add_danmakufu_my_funcs_to_dict(DanmakufuDict **dict) {
    DanmakufuDict *t;
    @<add_danmakufu_my_funcs_to_dict functions@>
}
@}

Функция загрузки скрипта:
@d danmakufu.h prototypes @{
DanmakufuMachine *danmakufu_load_file(char *filename);
@}

@d danmakufu.c functions @{
DanmakufuMachine *danmakufu_load_file(char *filename) {
    AstCons *cons = danmakufu_parse(filename);
    if(cons == NULL) {
        fprintf(stderr, "\ndanmakufu_parse error\n");
        exit(1);
    }

    DanmakufuMachine *machine = malloc(sizeof(DanmakufuMachine));
    if(machine == NULL) {
        fprintf(stderr, "\nCan't allocate memory for danmakufu_machine\n");
        exit(1);
    }

    machine->type = danmakufu_bytecode;
    machine->code = danmakufu_compile_to_bytecode(cons, &machine->code_size);

    machine->tasks = NULL;
    machine->last_task = NULL;

    add_danmakufu_v2_funcs_to_dict(&machine->global);
    add_danmakufu_my_funcs_to_dict(&machine->global);

    return machine;
}
@}
TODO: написать обработку ошибок при парсинге скрипта



Удалить последнюю в списке задачу у виртуальной машины:
@d danmakufu.c functions @{
static void danmakufu_remove_last_task(DanmakufuMachine *machine) {
    DanmakufuTask *t = machine->last_task;
    machine->last_task = machine->last_task->prev;

    danmakufu_tasks_free(t);
    danmakufu_tasks_pool_free_to_pool();

    if(machine->last_task == NULL)
        machine->tasks = NULL;
}
@}
если больше задач нет, то tasks = NULL

Переместить задачу на которую указывает tasks в конец списка и
изменить last_tasks на неё:
@d danmakufu.c functions @{
static void danmakufu_task_to_last_task(DanmakufuMachine *machine) {
    if(machine->tasks->next == NULL)
        return;

    machine->last_task->next = machine->tasks;
    machine->tasks->prev = machine->last_task;
    machine->last_task = machine->last_task->next;
    machine->tasks = machine->tasks->next;
    machine->last_task->next = NULL;
    machine->tasks->prev = NULL;
}
@}


@d danmakufu.c prototypes @{
static void danmakufu_stack_push(DanmakufuTask *task, void *el);@}

@d danmakufu.c functions @{
static void danmakufu_stack_push(DanmakufuTask *task, void *el) {
    if(task->sp == DANMAKUFU_TASK_STACK_SIZE) {
        fprintf(stderr, "\ndanmakufu_stack overflow\n");
        exit(1);
    }

    task->stack[task->sp] = el;
    task->sp++;
}
@}


@d danmakufu.c prototypes @{
static void *danmakufu_stack_pop(DanmakufuTask *task);@}

@d danmakufu.c functions @{
static void *danmakufu_stack_pop(DanmakufuTask *task) {
    if(task->sp == 0) {
        fprintf(stderr, "\ndanmakufu_stack is empty\n");
        exit(1);
    }

    task->sp--;
    return task->stack[task->sp];
}
@}

@d danmakufu.c functions @{
static void danmakufu_stack_drop(DanmakufuTask *task, int num) {
    if(task->sp == num-1) {
        fprintf(stderr, "\ndanmakufu_stack doesn't have %d elements. IP: %d\n", num, task->ip);
        exit(1);
    }

    task->sp -= num;
}
@}

Продублировать на стеке num последних элементов:
@d danmakufu.c functions @{
static void danmakufu_stack_dup(DanmakufuTask *task, int num) {
    if(task->sp == num-1) {
        fprintf(stderr, "\ndanmakufu_stack doesn't have %d elements. IP: %d\n", num, task->ip);
        exit(1);
    }

    int i;
    for(i = 0; i < num; i++)
        danmakufu_stack_push(task, task->stack[task->sp - num]);
}
@}

@d danmakufu.c prototypes @{
static double danmakufu_stack_add(DanmakufuTask *task, double num);@}

@d danmakufu.c functions @{
static double danmakufu_stack_add(DanmakufuTask *task, double num) {
    if(task->sp == 0) {
        fprintf(stderr, "\ndanmakufu_stack is empty\n");
        exit(1);
    }

    AstNumber* ast_num = task->stack[task->sp - 1];
    if(ast_num->type != ast_number) {
        fprintf(stderr, "\ndanmakufu_stack_add: incorrect type\n");
        exit(1);
    }

    ast_num->number += num;

    return ast_num->number;
}
@}

@d danmakufu.c functions @{
static void copy_stack(DanmakufuTask *from, DanmakufuTask *to) {
    int i;
    for(i = 0; i < from->sp; i++)
        to->stack[i] = ast_copy_obj(from->stack[i]);

    to->sp = from->sp;
}
@}


@d danmakufu.c prototypes @{
static void print_stack(DanmakufuTask *task);@}

@d danmakufu.c functions @{
static void print_stack(DanmakufuTask *task) {
    int i;

    printf("Stack (%p):", task);
    for(i = 0; i < task->sp; i++)
        printf(" "), ast_print(task->stack[i]);

    printf("\n");
}
@}

@d danmakufu.c functions @{
static void danmakufu_rstack_push(DanmakufuTask *task, int pos) {
    if(task->rp == DANMAKUFU_TASK_RSTACK_SIZE) {
        fprintf(stderr, "\ndanmakufu_rstack overflow\n");
        exit(1);
    }

    task->rstack[task->rp] = pos;
    task->rp++;
}
@}

@d danmakufu.c functions @{
static int danmakufu_rstack_pop(DanmakufuTask *task) {
    if(task->rp == 0) {
        fprintf(stderr, "\ndanmakufu_rstack is empty\n");
        exit(1);
    }

    task->rp--;
    return task->rstack[task->rp];
}
@}

@d danmakufu.c functions @{
static int rstack_empty(DanmakufuTask *task) {
    if(task->rp == 0)
        return 1;
    return 0;
}
@}

@d danmakufu.c prototypes @{
static void print_rstack(DanmakufuTask *task);@}

@d danmakufu.c functions @{
static void print_rstack(DanmakufuTask *task) {
    int i;

    printf("RStack (%p):", task);
    for(i = 0; i < task->rp; i++)
        printf(" %d", task->rstack[i]);

    printf("\n");
}
@}


Выполнить последний task. Вернёт 1, если task выполнился до конца:
@d danmakufu.c functions @{
static int danmakufu_eval_last_task(DanmakufuMachine *machine) {
    DanmakufuTask *t = machine->last_task;

    if(t->ip == machine->code_size)
        return 1;

    switch(machine->code[t->ip]) {
    @<danmakufu.c eval_last_task -- bytecodes@>
    case bc_setq: {
        // X <- Y
        void *X = danmakufu_stack_pop(t);
        void *Y = danmakufu_stack_pop(t);

        if(((AstSymbol*)X)->type != ast_symbol) {
            fprintf(stderr, "\nin bc_setq -- X isn't symbol\n");
            exit(1);
        }

        DanmakufuDict *d = danmakufu_dict_list_find_symbol(t->local, X);
        if(d == NULL) {
            d = danmakufu_dict_find_symbol(machine->global, X);
            if(d == NULL) {
                machine->global = danmakufu_dict_create(machine->global, X);
                d = machine->global;
            }
        }

        d->ptr = Y;

        t->ip++;
        break;
    }
    case bc_drop: {
        danmakufu_stack_drop(t, 1);
        t->ip++;
        break;
    }
    case bc_2drop: {
        danmakufu_stack_drop(t, 2);
        t->ip++;
        break;
    }
    case bc_dup: {
        danmakufu_stack_dup(t, 1);
        t->ip++;
        break;
    }
    case bc_2dup: {
        danmakufu_stack_dup(t, 2);
        t->ip++;
        break;
    }
    case bc_decl: {
        t->ip++;
        if(danmakufu_dict_find_symbol(t->local->dict, (AstSymbol*)machine->code[t->ip]) == NULL)
            t->local->dict = danmakufu_dict_create(t->local->dict,
                                                   (AstSymbol*)machine->code[t->ip]);
        t->ip++;
        break;
    }
    case bc_scope_push: {
        t->local = danmakufu_dict_list_create(t->local);
        t->ip++;
        break;
    }
    case bc_scope_pop: {
        DanmakufuDictList *d = t->local;
        t->local = t->local->next;
        danmakufu_dict_lists_free(d);
        t->ip++;
        break;
    }
    case bc_defun: {
        t->ip++;

        DanmakufuDict *d = danmakufu_dict_list_find_symbol(t->local,
                                                           (AstSymbol*)machine->code[t->ip]);
        if(d == NULL) {
            d = danmakufu_dict_find_symbol(machine->global, (AstSymbol*)machine->code[t->ip]);
            if(d == NULL) {
                 machine->global = danmakufu_dict_create(machine->global,
                                                         (AstSymbol*)machine->code[t->ip]);
                 d = machine->global;
            }
        }

        t->ip++;
        int after_func = machine->code[t->ip];
        t->ip++;
        d->ptr = ast_add_functions(t->ip);
        t->ip = after_func;
        break;
    }
    case bc_goto: {
        t->ip++;
        t->ip = machine->code[t->ip];
        break;
    }
    case bc_if: {
        t->ip++;
        AstNumber *ast_num = danmakufu_stack_pop(t);
        if(ast_num->type != ast_number) {
            fprintf(stderr, "\nbc_if: incorrect type\n");
            exit(1);
        }

        double number = ast_num->number;

        if(number == ast_true->number)
            t->ip++;
        else
            t->ip = machine->code[t->ip];
        break;
    }
    case bc_make_array: {
        t->ip++;
        int len = machine->code[t->ip];
        AstArray *arr = ast_add_arrays(len);

        int i;
        for(i = len-1; i > -1; i--)
            arr->arr[i] = danmakufu_stack_pop(t);
        break;
    }
    case bc_yield:
        t->ip++;
        return 0;
    case bc_inc:
        t->ip++;
        danmakufu_stack_add(t, 1);
        break;
    case bc_dec:
        t->ip++;
        danmakufu_stack_add(t, -1);
        break;
    default: {
        void *obj = (void*)machine->code[t->ip];
        int type = ((AstSymbol*)obj)->type;

        t->ip++;

        if(type == ast_symbol) {
            AstSymbol *symb = obj;

            DanmakufuDict *d = danmakufu_dict_list_find_symbol(t->local, symb);
            if(d == NULL) {
                d = danmakufu_dict_find_symbol(machine->global, symb);
                if(d == NULL) {
                    fprintf(stderr, "\n%s is unknown symbol\n", symb->name);
                    exit(1);
                }
            }
            obj = d->ptr;
            type = ((AstSymbol*)obj)->type;

            // if(type == ast_cfunction || type == ast_function)
            //     machine->code[t->ip-1] = (intptr_t)obj;
        }

        if(type == ast_cfunction)
            ((AstCFunction*)obj)->func(machine);
        else if(type == ast_function) {
            danmakufu_rstack_push(t, t->ip);
            t->ip = ((AstFunction*)obj)->p;
        }
        else if(type == ast_number ||
                type == ast_string ||
                type == ast_character ||
                type == ast_array)
            danmakufu_stack_push(t, ast_copy_obj(obj));
    }
    }

    return 0;
}
@}

@d danmakufu.c eval_last_task -- bytecodes @{
case bc_lit: {
    t->ip++;
    danmakufu_stack_push(t, ast_copy_obj((void*)machine->code[t->ip]));
    t->ip++;
    break;
}@}
bc_lit помещает в стек сырые данные. То есть их не надо заворачивать в ast_number,
  потому что само это число уже может быть ast_number

@d danmakufu.c eval_last_task -- bytecodes @{
case bc_repeat: {
    t->ip++;

    double number = danmakufu_stack_add(t, -1);

    if(number == -1.0)
        t->ip = machine->code[t->ip];
    else
        t->ip++;

    break;
}@}

@d danmakufu.c eval_last_task -- bytecodes @{
case bc_fork: {
    t->ip++;

    DanmakufuTask *new_task = danmakufu_create_new_task(machine->tasks);
    if(machine->tasks == NULL)
        machine->last_task = new_task;
    machine->tasks = new_task;

    danmakufu_dict_list_clear(new_task->local);
    new_task->local = copy_dict_list(t->local);

    copy_stack(t, new_task);
    new_task->ip = t->ip + 1;

    t->ip += machine->code[t->ip];

    break;
}@}

@d danmakufu.c eval_last_task -- bytecodes @{
case bc_ret: {
    if(rstack_empty(t))
        return 1;
    t->ip = danmakufu_rstack_pop(t);
    break;
}
@}

Выполнить одну итерацию байткода:
@d danmakufu.h prototypes @{
void danmakufu_run_one_iteration(DanmakufuMachine *machine, int *stop_flag);
@}
одна итерация - понятие растяжимое, danmakufu_run_one_iteration может вернуть
  выполнение в любой момент.
stop_flag - установка в 1 означает, что скрипт завершился и выполнять больше
  нечего.

@d danmakufu.c functions @{
void danmakufu_run_one_iteration(DanmakufuMachine *machine, int *stop_flag) {
    if(machine->tasks == NULL) {
        *stop_flag = 1;
        return;
    }

    danmakufu_task_to_last_task(machine);
    if(danmakufu_eval_last_task(machine))
        danmakufu_remove_last_task(machine);
}
@}

Создать новый task:
@d danmakufu.h prototypes @{
int danmakufu_add_task(DanmakufuMachine *machine, const char *func_name);
@}
func_name - имя функции с которой начнёт выполняться task. Скорее всего оно
  начинается на '@'. Если func_name == NULL, то начнёт выполняться с первой позиции
  байткода.
возвращает 1, если функция не найдена

@d danmakufu.c functions @{
int danmakufu_add_task(DanmakufuMachine *machine, const char *func_name) {
    DanmakufuTask *new_task = danmakufu_create_new_task(machine->tasks);

    if(func_name != NULL) {
        AstSymbol *symb = ast_add_symbol_to_tbl(func_name);
        DanmakufuDict *d = danmakufu_dict_find_symbol(machine->global, symb);
        if(d == NULL)
            return 1;

        AstFunction *func = d->ptr;

        if(func->type != ast_function) {
            fprintf(stderr, "\ndanmakufu_add_task: incorrect type\n");
            exit(1);
        }

        new_task->ip = func->p;
    }

    if(machine->tasks == NULL)
        machine->last_task = new_task;
    machine->tasks = new_task;

    return 0;
}
@}
FIXME: утечка task при возвращении 1

@d danmakufu.c danmakufu v2 functions @{
static void v2_gt(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_gt: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y->number > X->number ? ast_copy_obj(ast_true)
                                                    : ast_copy_obj(ast_false));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl(">"));
t->ptr = ast_add_cfunctions(v2_gt);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_lt(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_lt: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y->number < X->number ? ast_copy_obj(ast_true)
                                                    : ast_copy_obj(ast_false));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("<"));
t->ptr = ast_add_cfunctions(v2_lt);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_ge(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_ge: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y->number >= X->number ? ast_copy_obj(ast_true)
                                                     : ast_copy_obj(ast_false));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl(">="));
t->ptr = ast_add_cfunctions(v2_ge);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_le(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_le: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y->number <= X->number ? ast_copy_obj(ast_true)
                                                     : ast_copy_obj(ast_false));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("<="));
t->ptr = ast_add_cfunctions(v2_le);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_add(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_add: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(Y->number + X->number));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("add"));
t->ptr = ast_add_cfunctions(v2_add);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_subtract(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_subtract: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(Y->number - X->number));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("subtract"));
t->ptr = ast_add_cfunctions(v2_subtract);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_multiply(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_multiply: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(Y->number * X->number));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("multiply"));
t->ptr = ast_add_cfunctions(v2_multiply);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_divide(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_divide: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(Y->number / X->number));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("divide"));
t->ptr = ast_add_cfunctions(v2_divide);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_remainder(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_remainder: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number((int)Y->number % (int)X->number));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("remainder"));
t->ptr = ast_add_cfunctions(v2_remainder);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_successor(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    danmakufu_stack_add(cur, 1);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("successor"));
t->ptr = ast_add_cfunctions(v2_successor);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_predcessor(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    danmakufu_stack_add(cur, -1);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("predcessor"));
t->ptr = ast_add_cfunctions(v2_predcessor);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_power(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_power: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(pow(Y->number, X->number)));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("power"));
t->ptr = ast_add_cfunctions(v2_power);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_concatenate(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstString *X = danmakufu_stack_pop(cur);
    AstString *Y = danmakufu_stack_pop(cur);

    if(X->type == ast_string && Y->type == ast_string) {
        int szY = strlen(Y->str);
        int szX = strlen(X->str);

        Y->str = (char*)realloc(Y->str, szX + szY + 1);
        strncat(Y->str, X->str, szX);
        Y->str[szX + szY] = '\0';
    } else if(X->type == ast_array && Y->type == ast_array) {
        Y->arr = (void**)realloc(Y->arr, (X->len + Y->len)*sizeof(void*));
        memcpy(&(Y->arr[Y->len]), X->arr, (X->len + Y->len)*sizeof(void*));
        Y->len = X->len + Y->len;
    } else {
        fprintf(stderr, "\nv2_concatenate: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("concatenate"));
t->ptr = ast_add_cfunctions(v2_concatenate);@}

Напечатать элемент из ast:
@d danmakufu.c danmakufu my functions @{
static void my_print(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    void *X = danmakufu_stack_pop(cur);

    ast_print(X);
    printf("\n");
}
@}

@d add_danmakufu_my_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("special_print"));
t->ptr = ast_add_cfunctions(my_print);@}

@d danmakufu.c danmakufu my functions @{
static void my_stack(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    print_stack(cur);
}
@}

@d add_danmakufu_my_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("special_stack"));
t->ptr = ast_add_cfunctions(my_stack);@}

@d danmakufu.c danmakufu my functions @{
static void my_rstack(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    print_rstack(cur);
}
@}

@d add_danmakufu_my_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("special_rstack"));
t->ptr = ast_add_cfunctions(my_rstack);@}
