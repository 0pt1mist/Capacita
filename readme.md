# Capacita OS ENG
*A Cognitive, Capability-Based Operating System Concept*

Capacita OS is an experimental operating system architecture built upon the principles of the biological brain. We have discarded the 50‑year legacy of UNIX and Windows (files, folders, registries, UIDs) and created a system grounded in neuroplasticity, associative memory, and strict mathematical isolation.

The initial prototype is being developed for the OpenComputers environment (Lua), but the architecture is designed to be universal.

## Philosophy: OS as a Cognitive System

Classical operating systems force the machine to work with metaphors of a paper office (documents, folders, desks). Capacita OS works with metaphors of synapses and engrams.

### The Four Pillars of the Architecture

#### 1. Object Storage (Engrams Instead of Files)
Capacita has no paths like /home/user/docs/note.txt. The brain does not store memories in hierarchies; it stores them associatively. All data in the system are objects (engrams) attached to tags and metadata. You don’t search for a "file by path"; you ask the system: "Give me the object tagged #config and #network." This eliminates string parsing, "File Not Found" errors, and global namespaces.

#### 2. Capabilities as Synapses (Zero ACL Security)
Classical OS security relies on access control lists (User X can read File Y). This is slow and often insecure. Capacita has no users or traditional permissions. Security is built on a capability‑based model (through closures). If a process does not have a direct pointer (a synapse) to an object, that object simply does not exist in its address space. There is no way to “hack” something to which there is no mathematical path.

#### 3. Predictive Plasticity (Predictive Optimizer)
Instead of static file caching, the Capacita kernel behaves like a neural network. It uses Markov chains to analyse the call graph. If process A frequently requests object B after object C, the kernel physically reinforces that connection (by caching in RAM or creating a dedicated IPC channel). "Neurons that fire together, wire together" (Hebbian theory). The OS self‑optimises to the user’s patterns in real time.

#### 4. Isolation and "Let It Crash"
Programs are isolated actors. They do not share memory. They communicate only through asynchronous message passing (like neurotransmitters). If a driver or application encounters a critical error, its supervisor simply terminates and restarts the process. The whole system cannot crash.

## Architecture (Under the Hood)
- Kernel: microkernel / exokernel. Its only responsibilities are CPU scheduling (coroutines / multitasking) and IPC message delivery.
- Storage: semantic key‑value database over a flat disk space.
- Prototyping language: Lua 5.3 (OpenComputers API).

## Current Status
*Phase 1:* Proof of Concept (OpenComputers environment).
We are demonstrating that abandoning global namespaces and file‑oriented structures makes the kernel thinner, faster, and virtually immune to malware.

---
"We have stopped teaching computers to work like filing cabinets. We are teaching them to work like a mind."






# Capacita OS RUS
*A Cognitive, Capability-Based Operating System Concept*

Capacita OS — это экспериментальная архитектура операционной системы, построенная на принципах работы биологического мозга. Мы отбросили 50-летнее наследие UNIX и Windows (файлы, папки, реестры, UID) и создали систему, основанную на нейропластичности, ассоциативной памяти и строгой математической изоляции.

Первоначальный прототип разрабатывается для среды OpenComputers (Lua), но архитектура является универсальной.

## Философия: ОС как Когнитивная Система

Классические ОС заставляют машину работать с метафорами "бумажного офиса" (документ, папка, стол). Capacita OS работает с метафорами синапсов и энграмм.

### Четыре столпа архитектуры:

#### 1. Объектное хранилище (Энграммы вместо файлов)
В Capacita нет путей вроде /home/user/docs/note.txt. Мозг не хранит воспоминания в иерархиях, он хранит их ассоциативно.
Все данные в системе — это объекты (энграммы), привязанные к тегам и метаданным. Вы не ищете "файл по пути", вы запрашиваете у системы: *"Дай мне объект с тегами #config и #network"*. Это избавляет систему от парсинга строк, ошибок File Not Found и глобальных пространств имен.

#### 2. Капабилити как Синапсы (Zero ACL Security)
В классических ОС безопасность строится на списках доступа (Пользователь X имеет право читать Файл Y). Это медленно и небезопасно.
В Capacita нет пользователей и прав. Безопасность строится на *Capability-based* модели (через замыкания/closures). Если у процесса нет прямого указателя (синапса) на объект, этот объект для него физически не существует в адресном пространстве. Невозможно "взломать" то, к чему нет математического пути.

#### 3. Предсказательная Пластичность (Predictive Optimizer)
Вместо статичного кэширования файлов, ядро Capacita ведет себя как нейронная сеть.
Оно использует цепи Маркова для анализа графа вызовов. Если процесс А часто запрашивает объект Б после объекта В, ядро *физически усиливает эту связь* (кэширует в RAM или создает прямой IPC-канал). "Нейроны, которые срабатывают вместе — связываются вместе" (Правило Хебба). ОС самооптимизируется под паттерны пользователя в реальном времени.

#### 4. Изоляция и "Let it crash"
Программы — это изолированные акторы. Они не делят общую память. Они общаются только через асинхронный обмен сообщениями (подобно нейромедиаторам). Если драйвер или программа ловит критическую ошибку, её "супервизор" просто уничтожает и пересоздает процесс. Система не может упасть целиком.

## Архитектура (Under the Hood)
- Ядро: Микроядро / Экзоядро. Занимается только распределением процессорного времени (Корутины/Многозадачность) и передачей IPC-сообщений.
- FS: Семантическая база данных (Key-Value) поверх плоского дискового пространства.
- Язык прототипа: Lua 5.3 (OpenComputers API).

## Текущий статус
*Phase 1:* Proof of Concept (Среда OpenComputers).
Мы доказываем, что отказ от глобальных пространств имен и файловых структур делает код ядра тоньше, быстрее и абсолютно неуязвимым для вредоносного ПО.

---
*«Мы перестали учить компьютеры работать как шкафы с документами. Мы учим их работать как разум».*
