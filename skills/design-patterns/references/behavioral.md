# Behavioral Patterns

Behavioral patterns deal with algorithms and the assignment of responsibilities between objects.
They describe not just patterns of objects or classes, but also the patterns of communication
between them.

---

## Chain of Responsibility

**Intent:** Pass a request along a chain of handlers. Each handler decides either to process
the request or to pass it to the next handler in the chain.

**Participants:**
- **Handler** — defines an interface for handling requests; optionally implements the successor link
- **ConcreteHandler** — handles requests it is responsible for; forwards others to its successor
- **Client** — initiates the request to a ConcreteHandler object in the chain

**Key consideration:** The request may go unhandled if no handler in the chain processes it.
Whether this is a problem depends on context — sometimes a fallback handler at the end is needed.

**Example:**
```
// The handler interface declares a method for executing a
// request.
interface ComponentWithContextualHelp is
    method showHelp()


// The base class for simple components.
abstract class Component implements ComponentWithContextualHelp is
    field tooltipText: string

    // The component's container acts as the next link in the
    // chain of handlers.
    protected field container: Container

    // The component shows a tooltip if there's help text
    // assigned to it. Otherwise it forwards the call to the
    // container, if it exists.
    method showHelp() is
        if (tooltipText != null)
            // Show tooltip.
        else
            container.showHelp()


// Containers can contain both simple components and other
// containers as children. The chain relationships are
// established here. The class inherits showHelp behavior from
// its parent.
abstract class Container extends Component is
    protected field children: array of Component

    method add(child) is
        children.add(child)
        child.container = this


// Primitive components may be fine with default help
// implementation...
class Button extends Component is
    // ...

// But complex components may override the default
// implementation. If the help text can't be provided in a new
// way, the component can always call the base implementation
// (see Component class).
class Panel extends Container is
    field modalHelpText: string

    method showHelp() is
        if (modalHelpText != null)
            // Show a modal window with the help text.
        else
            super.showHelp()

// ...same as above...
class Dialog extends Container is
    field wikiPageURL: string

    method showHelp() is
        if (wikiPageURL != null)
            // Open the wiki help page.
        else
            super.showHelp()


// Client code.
class Application is
    // Every application configures the chain differently.
    method createUI() is
        dialog = new Dialog("Budget Reports")
        dialog.wikiPageURL = "http://..."
        panel = new Panel(0, 0, 400, 800)
        panel.modalHelpText = "This panel does..."
        ok = new Button(250, 760, 50, 20, "OK")
        ok.tooltipText = "This is an OK button that..."
        cancel = new Button(320, 760, 50, 20, "Cancel")
        // ...
        panel.add(ok)
        panel.add(cancel)
        dialog.add(panel)

    // Imagine what happens here.
    method onF1KeyPress() is
        component = this.getComponentAtMouseCoords()
        component.showHelp()
```

**When to use:**
- More than one object may handle a request, and the handler isn't known a priori
- You want to issue a request to one of several objects without specifying the receiver explicitly
- The set of objects that can handle a request should be specified dynamically

**When NOT to use:**
- When you need guaranteed handling — add a catch-all handler at the end of the chain
- When the chain is long and performance is critical (every request traverses all handlers)

**Related:** Composite (Chain of Responsibility is often applied to Composite), Command

---

## Command

**Intent:** Encapsulate a request as an object, thereby letting you parameterize clients with
different requests, queue or log requests, and support undoable operations.

**Participants:**
- **Command** — declares an interface for executing an operation
- **ConcreteCommand** — binds a Receiver object to an action; implements Execute by calling the Receiver
- **Client** — creates a ConcreteCommand and sets its Receiver
- **Invoker** — asks the command to carry out a request
- **Receiver** — knows how to perform the operations associated with carrying out a request

**Key consideration:** The key insight is decoupling *when* a request is made from *when* it
is executed. Undo/redo is implemented by storing executed commands and calling an Undo method.

**Example:**
```
// The base command class defines the common interface for all
// concrete commands.
abstract class Command is
    protected field app: Application
    protected field editor: Editor
    protected field backup: text

    constructor Command(app: Application, editor: Editor) is
        this.app = app
        this.editor = editor

    // Make a backup of the editor's state.
    method saveBackup() is
        backup = editor.text

    // Restore the editor's state.
    method undo() is
        editor.text = backup

    // The execution method is declared abstract to force all
    // concrete commands to provide their own implementations.
    // The method must return true or false depending on whether
    // the command changes the editor's state.
    abstract method execute()


// The concrete commands go here.
class CopyCommand extends Command is
    // The copy command isn't saved to the history since it
    // doesn't change the editor's state.
    method execute() is
        app.clipboard = editor.getSelection()
        return false

class CutCommand extends Command is
    // The cut command does change the editor's state, therefore
    // it must be saved to the history. And it'll be saved as
    // long as the method returns true.
    method execute() is
        saveBackup()
        app.clipboard = editor.getSelection()
        editor.deleteSelection()
        return true

class PasteCommand extends Command is
    method execute() is
        saveBackup()
        editor.replaceSelection(app.clipboard)
        return true

// The undo operation is also a command.
class UndoCommand extends Command is
    method execute() is
        app.undo()
        return false


// The global command history is just a stack.
class CommandHistory is
    private field history: array of Command

    // Last in...
    method push(c: Command) is
        // Push the command to the end of the history array.

    // ...first out
    method pop():Command is
        // Get the most recent command from the history.


// The editor class has actual text editing operations. It plays
// the role of a receiver: all commands end up delegating
// execution to the editor's methods.
class Editor is
    field text: string

    method getSelection() is
        // Return selected text.

    method deleteSelection() is
        // Delete selected text.

    method replaceSelection(text) is
        // Insert the clipboard's contents at the current
        // position.


// The application class sets up object relations. It acts as a
// sender: when something needs to be done, it creates a command
// object and executes it.
class Application is
    field clipboard: string
    field editors: array of Editors
    field activeEditor: Editor
    field history: CommandHistory

    // The code which assigns commands to UI objects may look
    // like this.
    method createUI() is
        // ...
        copy = function() { executeCommand(
            new CopyCommand(this, activeEditor)) }
        copyButton.setCommand(copy)
        shortcuts.onKeyPress("Ctrl+C", copy)

        cut = function() { executeCommand(
            new CutCommand(this, activeEditor)) }
        cutButton.setCommand(cut)
        shortcuts.onKeyPress("Ctrl+X", cut)

        paste = function() { executeCommand(
            new PasteCommand(this, activeEditor)) }
        pasteButton.setCommand(paste)
        shortcuts.onKeyPress("Ctrl+V", paste)

        undo = function() { executeCommand(
            new UndoCommand(this, activeEditor)) }
        undoButton.setCommand(undo)
        shortcuts.onKeyPress("Ctrl+Z", undo)

    // Execute a command and check whether it has to be added to
    // the history.
    method executeCommand(command) is
        if (command.execute())
            history.push(command)

    // Take the most recent command from the history and run its
    // undo method. Note that we don't know the class of that
    // command. But we don't have to, since the command knows
    // how to undo its own action.
    method undo() is
        command = history.pop()
        if (command != null)
            command.undo()
```

**When to use:**
- Parameterize objects by an action to perform (e.g., menu items, toolbar buttons)
- Queue, specify, and execute requests at different times
- Support undoable operations
- Support logging changes so they can be re-applied if the system crashes

**When NOT to use:**
- For simple method calls where encapsulation adds no benefit
- When undo/redo or queuing is not needed and the overhead isn't worth it

**Related:** Composite (MacroCommand), Memento (keeps state for undo), Prototype (commands
that must be copied)

---

## Interpreter

**Intent:** Given a language, define a representation for its grammar along with an interpreter
that uses the representation to interpret sentences in the language.

**Participants:**
- **AbstractExpression** — declares an Interpret operation
- **TerminalExpression** — implements Interpret for terminal symbols in the grammar
- **NonterminalExpression** — implements Interpret for non-terminal rules; holds child expressions
- **Context** — contains information that's global to the interpreter
- **Client** — builds the abstract syntax tree and invokes Interpret

**Key consideration:** Interpreter is worth reaching for when the grammar is simple and
relatively stable. For complex grammars, use a parser generator — Interpreter doesn't scale
well because each grammar rule requires a class.

**Example:**
```
// The context stores variable bindings used during interpretation.
// It acts as a shared lookup table across the entire expression tree.
class Context is
    private field variables: map of string to integer

    method assign(name: string, value: integer) is
        variables[name] = value

    method lookup(name: string): integer is
        return variables[name]


// The abstract expression interface declares a single interpret method.
// Every node in the expression tree — terminal or nonterminal — implements this.
interface Expression is
    method interpret(context: Context): integer


// Terminal expression: a literal integer constant.
// It is a leaf — it holds no child expressions.
class NumberExpression implements Expression is
    private field value: integer

    constructor NumberExpression(value: integer) is
        this.value = value

    method interpret(context: Context): integer is
        return value


// Terminal expression: a named variable.
// Delegates the actual value lookup to the context.
class VariableExpression implements Expression is
    private field name: string

    constructor VariableExpression(name: string) is
        this.name = name

    method interpret(context: Context): integer is
        return context.lookup(name)


// Nonterminal expression: addition.
// Holds two child expressions and combines their results.
class AddExpression implements Expression is
    private field left: Expression
    private field right: Expression

    constructor AddExpression(left: Expression, right: Expression) is
        this.left = left
        this.right = right

    method interpret(context: Context): integer is
        return left.interpret(context) + right.interpret(context)


// Nonterminal expression: multiplication.
class MultiplyExpression implements Expression is
    private field left: Expression
    private field right: Expression

    constructor MultiplyExpression(left: Expression, right: Expression) is
        this.left = left
        this.right = right

    method interpret(context: Context): integer is
        return left.interpret(context) * right.interpret(context)


// The client builds the abstract syntax tree by composing expression objects,
// then evaluates it by calling interpret on the root node.
// This example represents the expression: (x + 5) * y
class Application is
    method main() is
        context = new Context()
        context.assign("x", 3)
        context.assign("y", 4)

        // Construct AST manually (a real interpreter would parse source text).
        expression = new MultiplyExpression(
            new AddExpression(
                new VariableExpression("x"),
                new NumberExpression(5)),
            new VariableExpression("y"))

        result = expression.interpret(context)
        // result == (3 + 5) * 4 == 32
```

**When to use:**
- The grammar is simple
- Efficiency is not a critical concern
- You want to be able to easily extend or change the grammar

**When NOT to use:**
- Complex grammars — the class hierarchy becomes unwieldy
- Performance-critical scenarios — use a compiled parser instead

**Related:** Composite (the AST is a Composite), Iterator (traverses the AST), Visitor
(adds new operations to the AST without changing node classes)

---

## Iterator

**Intent:** Provide a way to access the elements of an aggregate object sequentially without
exposing its underlying representation.

**Participants:**
- **Iterator** — defines the interface for accessing and traversing elements
- **ConcreteIterator** — implements the Iterator interface; tracks current position
- **Aggregate** — defines an interface for creating an Iterator object
- **ConcreteAggregate** — implements the Iterator creation interface

**Key consideration:** Most modern languages build iterators directly into their collection
libraries (Python's `__iter__`, Java's `Iterable`, C#'s `IEnumerable`). The pattern is still
worth knowing conceptually — it's just often provided by the language rather than hand-rolled.

**Example:**
```
// The collection interface must declare a factory method for
// producing iterators. You can declare several methods if there
// are different kinds of iteration available in your program.
interface SocialNetwork is
    method createFriendsIterator(profileId):ProfileIterator
    method createCoworkersIterator(profileId):ProfileIterator


// Each concrete collection is coupled to a set of concrete
// iterator classes it returns. But the client isn't, since the
// signature of these methods returns iterator interfaces.
class Facebook implements SocialNetwork is
    // ... The bulk of the collection's code should go here ...

    // Iterator creation code.
    method createFriendsIterator(profileId) is
        return new FacebookIterator(this, profileId, "friends")
    method createCoworkersIterator(profileId) is
        return new FacebookIterator(this, profileId, "coworkers")


// The common interface for all iterators.
interface ProfileIterator is
    method getNext():Profile
    method hasMore():bool


// The concrete iterator class.
class FacebookIterator implements ProfileIterator is
    // The iterator needs a reference to the collection that it
    // traverses.
    private field facebook: Facebook
    private field profileId, type: string

    // An iterator object traverses the collection independently
    // from other iterators. Therefore it has to store the
    // iteration state.
    private field currentPosition
    private field cache: array of Profile

    constructor FacebookIterator(facebook, profileId, type) is
        this.facebook = facebook
        this.profileId = profileId
        this.type = type

    private method lazyInit() is
        if (cache == null)
            cache = facebook.socialGraphRequest(profileId, type)

    // Each concrete iterator class has its own implementation
    // of the common iterator interface.
    method getNext() is
        if (hasMore())
            result = cache[currentPosition]
            currentPosition++
            return result

    method hasMore() is
        lazyInit()
        return currentPosition < cache.length


// Here is another useful trick: you can pass an iterator to a
// client class instead of giving it access to a whole
// collection. This way, you don't expose the collection to the
// client.
//
// And there's another benefit: you can change the way the
// client works with the collection at runtime by passing it a
// different iterator. This is possible because the client code
// isn't coupled to concrete iterator classes.
class SocialSpammer is
    method send(iterator: ProfileIterator, message: string) is
        while (iterator.hasMore())
            profile = iterator.getNext()
            System.sendEmail(profile.getEmail(), message)


// The application class configures collections and iterators
// and then passes them to the client code.
class Application is
    field network: SocialNetwork
    field spammer: SocialSpammer

    method config() is
        if working with Facebook
            this.network = new Facebook()
        if working with LinkedIn
            this.network = new LinkedIn()
        this.spammer = new SocialSpammer()

    method sendSpamToFriends(profile) is
        iterator = network.createFriendsIterator(profile.getId())
        spammer.send(iterator, "Very important message")

    method sendSpamToCoworkers(profile) is
        iterator = network.createCoworkersIterator(profile.getId())
        spammer.send(iterator, "Very important message")
```

**When to use:**
- You want a uniform interface for traversing different aggregate structures
- You want to support multiple simultaneous traversals
- You want to decouple the traversal algorithm from the aggregate

**When NOT to use:**
- When the language's built-in iteration is sufficient (usually it is)

**Related:** Composite (Iterator traverses Composite trees), Factory Method (instantiating
the ConcreteIterator), Memento (Iterator can use Memento to capture traversal state)

---

## Mediator

**Intent:** Define an object that encapsulates how a set of objects interact. Mediator promotes
loose coupling by keeping objects from referring to each other explicitly.

**Participants:**
- **Mediator** — defines an interface for communicating with Colleague objects
- **ConcreteMediator** — implements cooperative behavior by coordinating Colleague objects
- **Colleague classes** — each knows its Mediator; communicates with it instead of other Colleagues

**Key consideration:** Mediator centralizes control — this is its strength and its risk. It can
simplify a complex web of interactions, but if not managed carefully, the Mediator itself
becomes a God Object that knows too much.

**Example:**
```
// The mediator interface declares a method used by components
// to notify the mediator about various events. The mediator may
// react to these events and pass the execution to other
// components.
interface Mediator is
    method notify(sender: Component, event: string)


// The concrete mediator class. The intertwined web of
// connections between individual components has been untangled
// and moved into the mediator.
class AuthenticationDialog implements Mediator is
    private field title: string
    private field loginOrRegisterChkBx: Checkbox
    private field loginUsername, loginPassword: Textbox
    private field registrationUsername, registrationPassword,
                  registrationEmail: Textbox
    private field okBtn, cancelBtn: Button

    constructor AuthenticationDialog() is
        // Create all component objects by passing the current
        // mediator into their constructors to establish links.

    // When something happens with a component, it notifies the
    // mediator. Upon receiving a notification, the mediator may
    // do something on its own or pass the request to another
    // component.
    method notify(sender, event) is
        if (sender == loginOrRegisterChkBx and event == "check")
            if (loginOrRegisterChkBx.checked)
                title = "Log in"
                // 1. Show login form components.
                // 2. Hide registration form components.
            else
                title = "Register"
                // 1. Show registration form components.
                // 2. Hide login form components

        if (sender == okBtn && event == "click")
            if (loginOrRegister.checked)
                // Try to find a user using login credentials.
                if (!found)
                    // Show an error message above the login
                    // field.
            else
                // 1. Create a user account using data from the
                // registration fields.
                // 2. Log that user in.
                // ...


// Components communicate with a mediator using the mediator
// interface. Thanks to that, you can use the same components in
// other contexts by linking them with different mediator
// objects.
class Component is
    field dialog: Mediator

    constructor Component(dialog) is
        this.dialog = dialog

    method click() is
        dialog.notify(this, "click")

    method keypress() is
        dialog.notify(this, "keypress")

// Concrete components don't talk to each other. They have only
// one communication channel, which is sending notifications to
// the mediator.
class Button extends Component is
    // ...

class Textbox extends Component is
    // ...

class Checkbox extends Component is
    method check() is
        dialog.notify(this, "check")
    // ...
```

**When to use:**
- Many objects communicate in complex, tangled ways; the result is hard to understand
- Reusing an object is difficult because it communicates with too many others
- You want to customize behavior distributed across several classes without subclassing

**When NOT to use:**
- When the interaction is simple — adding a mediator adds unnecessary indirection
- When the mediator itself grows too complex to maintain

**Related:** Facade (abstracts a subsystem's interface; Mediator abstracts peer communication),
Observer (Mediator can use Observer to notify colleagues)

---

## Memento

**Intent:** Without violating encapsulation, capture and externalize an object's internal state
so that the object can be restored to this state later.

**Participants:**
- **Originator** — creates a Memento containing a snapshot of its internal state; uses Memento to restore state
- **Memento** — stores the Originator's internal state; protects against access by other than the Originator
- **Caretaker** — is responsible for the Memento's safekeeping; never operates on or examines its contents

**Key consideration:** Mementos can be expensive if the Originator has a large amount of state.
An incremental approach (store only the delta) can mitigate this at the cost of complexity.

**Example:**
```
// The originator holds some important data that may change over
// time. It also defines a method for saving its state inside a
// memento and another method for restoring the state from it.
class Editor is
    private field text, curX, curY, selectionWidth

    method setText(text) is
        this.text = text

    method setCursor(x, y) is
        this.curX = x
        this.curY = y

    method setSelectionWidth(width) is
        this.selectionWidth = width

    // Saves the current state inside a memento.
    method createSnapshot():Snapshot is
        // Memento is an immutable object; that's why the
        // originator passes its state to the memento's
        // constructor parameters.
        return new Snapshot(this, text, curX, curY, selectionWidth)

// The memento class stores the past state of the editor.
class Snapshot is
    private field editor: Editor
    private field text, curX, curY, selectionWidth

    constructor Snapshot(editor, text, curX, curY, selectionWidth) is
        this.editor = editor
        this.text = text
        this.curX = x
        this.curY = y
        this.selectionWidth = selectionWidth

    // At some point, a previous state of the editor can be
    // restored using a memento object.
    method restore() is
        editor.setText(text)
        editor.setCursor(curX, curY)
        editor.setSelectionWidth(selectionWidth)

// A command object can act as a caretaker. In that case, the
// command gets a memento just before it changes the
// originator's state. When undo is requested, it restores the
// originator's state from a memento.
class Command is
    private field backup: Snapshot

    method makeBackup() is
        backup = editor.createSnapshot()

    method undo() is
        if (backup != null)
            backup.restore()
    // ...
```

**When to use:**
- A snapshot of an object's state must be saved so it can be restored later
- A direct interface to obtaining the state would expose implementation details

**When NOT to use:**
- When restoring state is cheap (just reconstruct the object)
- When the state is large and delta approaches are too complex to implement

**Related:** Command (using Memento for undo), Iterator (Memento can capture iterator state)

---

## Observer

**Intent:** Define a one-to-many dependency between objects so that when one object changes
state, all its dependents are notified and updated automatically.

**Participants:**
- **Subject** — knows its observers; provides interface for attaching/detaching observers
- **Observer** — defines an updating interface for objects that should be notified
- **ConcreteSubject** — stores state of interest to ConcreteObservers; notifies observers on change
- **ConcreteObserver** — maintains a reference to a ConcreteSubject; stores state consistent with Subject's

**Key consideration:** The classic push vs. pull question: does the Subject push data in the
notification, or do Observers pull what they need? Push is simpler; pull gives Observers more
control. Most modern event systems push a minimal event object and let handlers pull details.

**Example:**
```
// The base publisher class includes subscription management
// code and notification methods.
class EventManager is
    private field listeners: hash map of event types and listeners

    method subscribe(eventType, listener) is
        listeners.add(eventType, listener)

    method unsubscribe(eventType, listener) is
        listeners.remove(eventType, listener)

    method notify(eventType, data) is
        foreach (listener in listeners.of(eventType)) do
            listener.update(data)

// The concrete publisher contains real business logic that's
// interesting for some subscribers. We could derive this class
// from the base publisher, but that isn't always possible in
// real life because the concrete publisher might already be a
// subclass. In this case, you can patch the subscription logic
// in with composition, as we did here.
class Editor is
    public field events: EventManager
    private field file: File

    constructor Editor() is
        events = new EventManager()

    // Methods of business logic can notify subscribers about
    // changes.
    method openFile(path) is
        this.file = new File(path)
        events.notify("open", file.name)

    method saveFile() is
        file.write()
        events.notify("save", file.name)

    // ...


// Here's the subscriber interface. If your programming language
// supports functional types, you can replace the whole
// subscriber hierarchy with a set of functions.
interface EventListener is
    method update(filename)

// Concrete subscribers react to updates issued by the publisher
// they are attached to.
class LoggingListener implements EventListener is
    private field log: File
    private field message: string

    constructor LoggingListener(log_filename, message) is
        this.log = new File(log_filename)
        this.message = message

    method update(filename) is
        log.write(replace('%s',filename,message))

class EmailAlertsListener implements EventListener is
    private field email: string
    private field message: string

    constructor EmailAlertsListener(email, message) is
        this.email = email
        this.message = message

    method update(filename) is
        system.email(email, replace('%s',filename,message))


// An application can configure publishers and subscribers at
// runtime.
class Application is
    method config() is
        editor = new Editor()

        logger = new LoggingListener(
            "/path/to/log.txt",
            "Someone has opened the file: %s")
        editor.events.subscribe("open", logger)

        emailAlerts = new EmailAlertsListener(
            "admin@example.com",
            "Someone has changed the file: %s")
        editor.events.subscribe("save", emailAlerts)
```

**When to use:**
- A change to one object requires changing others, and you don't know how many
- An object should notify other objects without making assumptions about who they are
- You're building event/message systems, reactive UIs, pub/sub systems

**When NOT to use:**
- When the dependency is simple and stable — a direct call is clearer
- When notification storms could be a problem (a change triggers a chain of cascading updates)

**Related:** Mediator (avoids tangled dependencies; Mediator centralizes what Observer
distributes), Singleton (Subject is often a Singleton)

---

## State

**Intent:** Allow an object to alter its behavior when its internal state changes. The object
will appear to change its class.

**Participants:**
- **Context** — defines the interface of interest to clients; maintains a ConcreteState instance
- **State** — defines an interface for encapsulating the behavior associated with a particular state
- **ConcreteState** — each subclass implements a behavior associated with a state of Context

**Key consideration:** State transitions can be defined by ConcreteState classes or by the
Context. Having ConcreteStates control transitions decouples the Context from state-transition
logic; having the Context control transitions makes transition rules easier to see in one place.

**Example:**
```
// The AudioPlayer class acts as a context. It also maintains a
// reference to an instance of one of the state classes that
// represents the current state of the audio player.
class AudioPlayer is
    field state: State
    field UI, volume, playlist, currentSong

    constructor AudioPlayer() is
        this.state = new ReadyState(this)

        // Context delegates handling user input to a state
        // object. Naturally, the outcome depends on what state
        // is currently active, since each state can handle the
        // input differently.
        UI = new UserInterface()
        UI.lockButton.onClick(this.clickLock)
        UI.playButton.onClick(this.clickPlay)
        UI.nextButton.onClick(this.clickNext)
        UI.prevButton.onClick(this.clickPrevious)

    // Other objects must be able to switch the audio player's
    // active state.
    method changeState(state: State) is
        this.state = state

    // UI methods delegate execution to the active state.
    method clickLock() is
        state.clickLock()
    method clickPlay() is
        state.clickPlay()
    method clickNext() is
        state.clickNext()
    method clickPrevious() is
        state.clickPrevious()

    // A state may call some service methods on the context.
    method startPlayback() is
        // ...
    method stopPlayback() is
        // ...
    method nextSong() is
        // ...
    method previousSong() is
        // ...
    method fastForward(time) is
        // ...
    method rewind(time) is
        // ...


// The base state class declares methods that all concrete
// states should implement and also provides a backreference to
// the context object associated with the state. States can use
// the backreference to transition the context to another state.
abstract class State is
    protected field player: AudioPlayer

    // Context passes itself through the state constructor. This
    // may help a state fetch some useful context data if it's
    // needed.
    constructor State(player) is
        this.player = player

    abstract method clickLock()
    abstract method clickPlay()
    abstract method clickNext()
    abstract method clickPrevious()


// Concrete states implement various behaviors associated with a
// state of the context.
class LockedState extends State is

    // When you unlock a locked player, it may assume one of two
    // states.
    method clickLock() is
        if (player.playing)
            player.changeState(new PlayingState(player))
        else
            player.changeState(new ReadyState(player))

    method clickPlay() is
        // Locked, so do nothing.

    method clickNext() is
        // Locked, so do nothing.

    method clickPrevious() is
        // Locked, so do nothing.


// They can also trigger state transitions in the context.
class ReadyState extends State is
    method clickLock() is
        player.changeState(new LockedState(player))

    method clickPlay() is
        player.startPlayback()
        player.changeState(new PlayingState(player))

    method clickNext() is
        player.nextSong()

    method clickPrevious() is
        player.previousSong()


class PlayingState extends State is
    method clickLock() is
        player.changeState(new LockedState(player))

    method clickPlay() is
        player.stopPlayback()
        player.changeState(new ReadyState(player))

    method clickNext() is
        if (event.doubleclick)
            player.nextSong()
        else
            player.fastForward(5)

    method clickPrevious() is
        if (event.doubleclick)
            player.previous()
        else
            player.rewind(5)
```

**When to use:**
- An object's behavior depends on its state and must change at runtime
- Operations have large, multi-part conditionals that depend on object state
  (State eliminates the conditionals)

**When NOT to use:**
- When the number of states is small and transitions are simple — a flag and a few `if` statements may be clearer
- When state-specific behavior is trivial

**Related:** Flyweight (State objects can be shared as Flyweights), Singleton (ConcreteState
subclasses are often Singletons), Strategy (similar structure; Strategy changes the algorithm,
State changes the object's behavior based on internal state)

---

## Strategy

**Intent:** Define a family of algorithms, encapsulate each one, and make them interchangeable.
Strategy lets the algorithm vary independently from clients that use it.

**Participants:**
- **Strategy** — declares an interface common to all supported algorithms
- **ConcreteStrategy** — implements the algorithm using the Strategy interface
- **Context** — is configured with a ConcreteStrategy; may define an interface to let Strategy access its data

**Key consideration:** Strategy eliminates conditionals — instead of `if type == 'A' do X else do Y`,
you configure the Context with the appropriate Strategy. Strategies can be swapped at runtime.

**Example:**
```
// The strategy interface declares operations common to all
// supported versions of some algorithm. The context uses this
// interface to call the algorithm defined by the concrete
// strategies.
interface Strategy is
    method execute(a, b)

// Concrete strategies implement the algorithm while following
// the base strategy interface. The interface makes them
// interchangeable in the context.
class ConcreteStrategyAdd implements Strategy is
    method execute(a, b) is
        return a + b

class ConcreteStrategySubtract implements Strategy is
    method execute(a, b) is
        return a - b

class ConcreteStrategyMultiply implements Strategy is
    method execute(a, b) is
        return a * b

// The context defines the interface of interest to clients.
class Context is
    // The context maintains a reference to one of the strategy
    // objects. The context doesn't know the concrete class of a
    // strategy. It should work with all strategies via the
    // strategy interface.
    private strategy: Strategy

    // Usually the context accepts a strategy through the
    // constructor, and also provides a setter so that the
    // strategy can be switched at runtime.
    method setStrategy(Strategy strategy) is
        this.strategy = strategy

    // The context delegates some work to the strategy object
    // instead of implementing multiple versions of the
    // algorithm on its own.
    method executeStrategy(int a, int b) is
        return strategy.execute(a, b)


// The client code picks a concrete strategy and passes it to
// the context. The client should be aware of the differences
// between strategies in order to make the right choice.
class ExampleApplication is
    method main() is
        Create context object.

        Read first number.
        Read last number.
        Read the desired action from user input.

        if (action == addition) then
            context.setStrategy(new ConcreteStrategyAdd())

        if (action == subtraction) then
            context.setStrategy(new ConcreteStrategySubtract())

        if (action == multiplication) then
            context.setStrategy(new ConcreteStrategyMultiply())

        result = context.executeStrategy(First number, Second number)

        Print result.
```

**When to use:**
- Many related classes differ only in their behavior
- You need different variants of an algorithm
- An algorithm uses data that clients shouldn't know about
- A class defines many behaviors via conditionals that can be moved into Strategy classes

**When NOT to use:**
- When there are only 1–2 algorithms and they're unlikely to change (Strategy adds indirection without payoff)
- When clients must be aware of how Strategies differ to select appropriately

**Related:** Bridge (similar structure; Bridge separates interface from implementation,
Strategy separates an algorithm from its context), Decorator (both change behavior;
Decorator changes the skin, Strategy changes the guts), Flyweight (Strategies can be Flyweights)

---

## Template Method

**Intent:** Define the skeleton of an algorithm in an operation, deferring some steps to
subclasses. Template Method lets subclasses redefine certain steps of an algorithm without
changing the algorithm's structure.

**Participants:**
- **AbstractClass** — defines abstract primitive operations that ConcreteClasses implement;
  implements a template method defining the skeleton of an algorithm
- **ConcreteClass** — implements the primitive operations to carry out specific steps

**Key consideration:** Template Method relies on inheritance — the skeleton lives in the
parent. This can make the algorithm harder to follow (logic spread across the hierarchy).
Hooks (optional override points with default implementations) give subclasses additional
flexibility without requiring overrides.

**Example:**
```
// The abstract class defines a template method that contains a
// skeleton of some algorithm composed of calls, usually to
// abstract primitive operations. Concrete subclasses implement
// these operations, but leave the template method itself
// intact.
class GameAI is
    // The template method defines the skeleton of an algorithm.
    method turn() is
        collectResources()
        buildStructures()
        buildUnits()
        attack()

    // Some of the steps may be implemented right in a base
    // class.
    method collectResources() is
        foreach (s in this.builtStructures) do
            s.collect()

    // And some of them may be defined as abstract.
    abstract method buildStructures()
    abstract method buildUnits()

    // A class can have several template methods.
    method attack() is
        enemy = closestEnemy()
        if (enemy == null)
            sendScouts(map.center)
        else
            sendWarriors(enemy.position)

    abstract method sendScouts(position)
    abstract method sendWarriors(position)

// Concrete classes have to implement all abstract operations of
// the base class but they must not override the template method
// itself.
class OrcsAI extends GameAI is
    method buildStructures() is
        if (there are some resources) then
            // Build farms, then barracks, then stronghold.

    method buildUnits() is
        if (there are plenty of resources) then
            if (there are no scouts)
                // Build peon, add it to scouts group.
            else
                // Build grunt, add it to warriors group.

    // ...

    method sendScouts(position) is
        if (scouts.length > 0) then
            // Send scouts to position.

    method sendWarriors(position) is
        if (warriors.length > 5) then
            // Send warriors to position.

// Subclasses can also override some operations with a default
// implementation.
class MonstersAI extends GameAI is
    method collectResources() is
        // Monsters don't collect resources.

    method buildStructures() is
        // Monsters don't build structures.

    method buildUnits() is
        // Monsters don't build units.
```

**When to use:**
- You want to implement the invariant parts of an algorithm once and let subclasses fill in variant parts
- When to factor out common behavior in subclasses to avoid duplication
- You want to control which points subclasses can extend (vs. making everything overridable)

**When NOT to use:**
- When you need to vary the algorithm structure at runtime (use Strategy instead)
- When inheritance is already being used for another purpose

**Related:** Factory Method (is a specialization of Template Method), Strategy (Template
Method uses inheritance; Strategy uses composition)

---

## Visitor

**Intent:** Represent an operation to be performed on elements of an object structure. Visitor
lets you define a new operation without changing the classes of the elements on which it operates.

**Participants:**
- **Visitor** — declares a Visit operation for each ConcreteElement class
- **ConcreteVisitor** — implements each operation declared by Visitor
- **Element** — defines an Accept operation that takes a Visitor as an argument
- **ConcreteElement** — implements an Accept operation that calls the visiting operation on the Visitor
- **ObjectStructure** — can enumerate its elements; may provide a high-level interface to allow Visitors to visit its elements

**Key consideration:** Visitor makes adding new operations easy but makes adding new ConcreteElement
classes hard (every Visitor must be updated). It's the inverse of the usual OOP tradeoff (where
adding a class is easy but adding an operation is hard).

**Example:**
```
// The element interface declares an `accept` method that takes
// the base visitor interface as an argument.
interface Shape is
    method move(x, y)
    method draw()
    method accept(v: Visitor)

// Each concrete element class must implement the `accept`
// method in such a way that it calls the visitor's method that
// corresponds to the element's class.
class Dot implements Shape is
    // ...

    // Note that we're calling `visitDot`, which matches the
    // current class name. This way we let the visitor know the
    // class of the element it works with.
    method accept(v: Visitor) is
        v.visitDot(this)

class Circle implements Shape is
    // ...
    method accept(v: Visitor) is
        v.visitCircle(this)

class Rectangle implements Shape is
    // ...
    method accept(v: Visitor) is
        v.visitRectangle(this)

class CompoundShape implements Shape is
    // ...
    method accept(v: Visitor) is
        v.visitCompoundShape(this)


// The Visitor interface declares a set of visiting methods that
// correspond to element classes. The signature of a visiting
// method lets the visitor identify the exact class of the
// element that it's dealing with.
interface Visitor is
    method visitDot(d: Dot)
    method visitCircle(c: Circle)
    method visitRectangle(r: Rectangle)
    method visitCompoundShape(cs: CompoundShape)

// Concrete visitors implement several versions of the same
// algorithm, which can work with all concrete element classes.
//
// You can experience the biggest benefit of the Visitor pattern
// when using it with a complex object structure such as a
// Composite tree. In this case, it might be helpful to store
// some intermediate state of the algorithm while executing the
// visitor's methods over various objects of the structure.
class XMLExportVisitor implements Visitor is
    method visitDot(d: Dot) is
        // Export the dot's ID and center coordinates.

    method visitCircle(c: Circle) is
        // Export the circle's ID, center coordinates and
        // radius.

    method visitRectangle(r: Rectangle) is
        // Export the rectangle's ID, left-top coordinates,
        // width and height.

    method visitCompoundShape(cs: CompoundShape) is
        // Export the shape's ID as well as the list of its
        // children's IDs.


// The client code can run visitor operations over any set of
// elements without figuring out their concrete classes. The
// accept operation directs a call to the appropriate operation
// in the visitor object.
class Application is
    field allShapes: array of Shapes

    method export() is
        exportVisitor = new XMLExportVisitor()

        foreach (shape in allShapes) do
            shape.accept(exportVisitor)
```

**When to use:**
- Many distinct and unrelated operations need to be performed on an object structure without
  polluting their classes
- Object structure classes change rarely, but you often need to add new operations
- Object structure contains many classes with differing interfaces you want to perform operations over

**When NOT to use:**
- When the object structure changes frequently (adding new element classes breaks all Visitors)
- When the operations are tightly coupled to the element classes

**Related:** Composite (Visitor is applied to Composite structures), Interpreter (Visitor
can be used to apply operations to an AST)
