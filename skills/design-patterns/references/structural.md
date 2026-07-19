# Structural Patterns

Structural patterns deal with object composition — how classes and objects are assembled to
form larger structures while keeping those structures flexible and efficient.

---

## Adapter

**Intent:** Convert the interface of a class into another interface clients expect. Lets
classes work together that couldn't otherwise because of incompatible interfaces.

**Participants:**
- **Target** — the interface the client expects
- **Adaptee** — the existing class with an incompatible interface
- **Adapter** — wraps the Adaptee and implements the Target interface
- **Client** — collaborates with objects via the Target interface

**Two forms:**
- **Object Adapter** — wraps an Adaptee instance (composition; more flexible, preferred in
  most languages)
- **Class Adapter** — inherits from both Target and Adaptee (multiple inheritance; less common)

**Example:**
```
// Say you have two classes with compatible interfaces:
// RoundHole and RoundPeg.
class RoundHole is
    constructor RoundHole(radius) { ... }

    method getRadius() is
        // Return the radius of the hole.

    method fits(peg: RoundPeg) is
        return this.getRadius() >= peg.getRadius()

class RoundPeg is
    constructor RoundPeg(radius) { ... }

    method getRadius() is
        // Return the radius of the peg.


// But there's an incompatible class: SquarePeg.
class SquarePeg is
    constructor SquarePeg(width) { ... }

    method getWidth() is
        // Return the square peg width.


// An adapter class lets you fit square pegs into round holes.
// It extends the RoundPeg class to let the adapter objects act
// as round pegs.
class SquarePegAdapter extends RoundPeg is
    // In reality, the adapter contains an instance of the
    // SquarePeg class.
    private field peg: SquarePeg

    constructor SquarePegAdapter(peg: SquarePeg) is
        this.peg = peg

    method getRadius() is
        // The adapter pretends that it's a round peg with a
        // radius that could fit the square peg that the adapter
        // actually wraps.
        return peg.getWidth() * Math.sqrt(2) / 2


// Somewhere in client code.
hole = new RoundHole(5)
rpeg = new RoundPeg(5)
hole.fits(rpeg) // true

small_sqpeg = new SquarePeg(5)
large_sqpeg = new SquarePeg(10)
hole.fits(small_sqpeg) // this won't compile (incompatible types)

small_sqpeg_adapter = new SquarePegAdapter(small_sqpeg)
large_sqpeg_adapter = new SquarePegAdapter(large_sqpeg)
hole.fits(small_sqpeg_adapter) // true
hole.fits(large_sqpeg_adapter) // false
```

**When to use:**
- You want to use an existing class but its interface doesn't match
- You're integrating a third-party library without modifying it
- You need reusable code that cooperates with unrelated or unforeseen classes

**When NOT to use:**
- When you can simply modify the Adaptee (no legacy constraints, no external library)

**Related:** Bridge (similar structure, but Bridge is designed upfront; Adapter retrofits),
Decorator (wraps an object but adds behavior rather than translating interfaces), Proxy

---

## Bridge

**Intent:** Decouple an abstraction from its implementation so the two can vary independently.

**Participants:**
- **Abstraction** — defines the abstraction's interface; holds a reference to an Implementor
- **RefinedAbstraction** — extends Abstraction with additional behavior
- **Implementor** — defines the interface for implementation classes (doesn't have to match
  Abstraction's interface)
- **ConcreteImplementor** — provides a specific implementation

**Structure:**
```
Abstraction ---------> Implementor
     |                      |
RefinedAbstraction   ConcreteImplementorA
                     ConcreteImplementorB
```

**Key consideration:** Bridge avoids a combinatorial explosion of subclasses. Without it,
supporting M abstractions × N implementations requires M×N classes. With Bridge, you have
M + N classes.

**Example:**
```
// The "abstraction" defines the interface for the "control"
// part of the two class hierarchies. It maintains a reference
// to an object of the "implementation" hierarchy and delegates
// all of the real work to this object.
class RemoteControl is
    protected field device: Device
    constructor RemoteControl(device: Device) is
        this.device = device
    method togglePower() is
        if (device.isEnabled()) then
            device.disable()
        else
            device.enable()
    method volumeDown() is
        device.setVolume(device.getVolume() - 10)
    method volumeUp() is
        device.setVolume(device.getVolume() + 10)
    method channelDown() is
        device.setChannel(device.getChannel() - 1)
    method channelUp() is
        device.setChannel(device.getChannel() + 1)


// You can extend classes from the abstraction hierarchy
// independently from device classes.
class AdvancedRemoteControl extends RemoteControl is
    method mute() is
        device.setVolume(0)


// The "implementation" interface declares methods common to all
// concrete implementation classes. It doesn't have to match the
// abstraction's interface. In fact, the two interfaces can be
// entirely different. Typically the implementation interface
// provides only primitive operations, while the abstraction
// defines higher-level operations based on those primitives.
interface Device is
    method isEnabled()
    method enable()
    method disable()
    method getVolume()
    method setVolume(percent)
    method getChannel()
    method setChannel(channel)


// All devices follow the same interface.
class Tv implements Device is
    // ...

class Radio implements Device is
    // ...


// Somewhere in client code.
tv = new Tv()
remote = new RemoteControl(tv)
remote.togglePower()

radio = new Radio()
remote = new AdvancedRemoteControl(radio)
```

**When to use:**
- You want to avoid a permanent binding between abstraction and implementation
- Both abstraction and implementation should be extensible via subclassing
- Changes in implementation shouldn't impact client code

**When NOT to use:**
- Simple class hierarchies where the explosion problem doesn't arise

**Related:** Abstract Factory (can create and configure a Bridge), Adapter (retrofits;
Bridge is upfront design), Strategy (similar structure; Strategy varies an algorithm,
Bridge varies implementation)

---

## Composite

**Intent:** Compose objects into tree structures to represent part-whole hierarchies. Lets
clients treat individual objects and compositions uniformly.

**Participants:**
- **Component** — declares the interface for objects in the composition; optional default behavior
- **Leaf** — a leaf node; has no children; does the actual work
- **Composite** — stores child components; implements child-related operations; delegates to children
- **Client** — manipulates objects through the Component interface

**Key consideration:** The power of Composite is that the client doesn't need to distinguish
between a Leaf and a Composite. Both respond to the same interface. The tradeoff is that it
can make your design overly general — adding type constraints between components becomes
harder.

**Example:**
```
// The component interface declares common operations for both
// simple and complex objects of a composition.
interface Graphic is
    method move(x, y)
    method draw()

// The leaf class represents end objects of a composition. A
// leaf object can't have any sub-objects. Usually, it's leaf
// objects that do the actual work, while composite objects only
// delegate to their sub-components.
class Dot implements Graphic is
    field x, y

    constructor Dot(x, y) { ... }

    method move(x, y) is
        this.x += x, this.y += y

    method draw() is
        // Draw a dot at X and Y.

// All component classes can extend other components.
class Circle extends Dot is
    field radius

    constructor Circle(x, y, radius) { ... }

    method draw() is
        // Draw a circle at X and Y with radius R.

// The composite class represents complex components that may
// have children. Composite objects usually delegate the actual
// work to their children and then "sum up" the result.
class CompoundGraphic implements Graphic is
    field children: array of Graphic

    // A composite object can add or remove other components
    // (both simple or complex) to or from its child list.
    method add(child: Graphic) is
        // Add a child to the array of children.

    method remove(child: Graphic) is
        // Remove a child from the array of children.

    method move(x, y) is
        foreach (child in children) do
            child.move(x, y)

    // A composite executes its primary logic in a particular
    // way. It traverses recursively through all its children,
    // collecting and summing up their results. Since the
    // composite's children pass these calls to their own
    // children and so forth, the whole object tree is traversed
    // as a result.
    method draw() is
        // 1. For each child component:
        //     - Draw the component.
        //     - Update the bounding rectangle.
        // 2. Draw a dashed rectangle using the bounding
        // coordinates.


// The client code works with all the components via their base
// interface. This way the client code can support simple leaf
// components as well as complex composites.
class ImageEditor is
    field all: CompoundGraphic

    method load() is
        all = new CompoundGraphic()
        all.add(new Dot(1, 2))
        all.add(new Circle(5, 3, 10))
        // ...

    // Combine selected components into one complex composite
    // component.
    method groupSelected(components: array of Graphic) is
        group = new CompoundGraphic()
        foreach (component in components) do
            group.add(component)
            all.remove(component)
        all.add(group)
        // All components will be drawn.
        all.draw()
```

**When to use:**
- You want to represent part-whole hierarchies (file systems, UI widgets, org charts)
- You want clients to ignore the difference between compositions of objects and individual objects

**When NOT to use:**
- When the tree structure is simple or fixed — the added abstraction may not pay off
- When you need strict type constraints on what can contain what

**Related:** Decorator (adds responsibilities to objects; can be combined with Composite),
Iterator (traverses Composite trees), Visitor (adds operations to Composite structures)

---

## Decorator

**Intent:** Attach additional responsibilities to an object dynamically. Decorators provide
a flexible alternative to subclassing for extending functionality.

**Participants:**
- **Component** — defines the interface for objects that can have responsibilities added
- **ConcreteComponent** — the base object to which responsibilities are attached
- **Decorator** — maintains a reference to a Component; implements the Component interface
- **ConcreteDecorator** — adds responsibilities to the component

**Key consideration:** Decorators can be stacked — each one wraps the previous and adds
behavior. But a deeply stacked decorator chain can be hard to debug. A decorator and its
component are not identical — `instanceof` or type checks can break down.

**Example:**
```
// The component interface defines operations that can be
// altered by decorators.
interface DataSource is
    method writeData(data)
    method readData():data

// Concrete components provide default implementations for the
// operations. There might be several variations of these
// classes in a program.
class FileDataSource implements DataSource is
    constructor FileDataSource(filename) { ... }

    method writeData(data) is
        // Write data to file.

    method readData():data is
        // Read data from file.

// The base decorator class follows the same interface as the
// other components. The primary purpose of this class is to
// define the wrapping interface for all concrete decorators.
// The default implementation of the wrapping code might include
// a field for storing a wrapped component and the means to
// initialize it.
class DataSourceDecorator implements DataSource is
    protected field wrappee: DataSource

    constructor DataSourceDecorator(source: DataSource) is
        wrappee = source

    // The base decorator simply delegates all work to the
    // wrapped component. Extra behaviors can be added in
    // concrete decorators.
    method writeData(data) is
        wrappee.writeData(data)

    // Concrete decorators may call the parent implementation of
    // the operation instead of calling the wrapped object
    // directly. This approach simplifies extension of decorator
    // classes.
    method readData():data is
        return wrappee.readData()

// Concrete decorators must call methods on the wrapped object,
// but may add something of their own to the result. Decorators
// can execute the added behavior either before or after the
// call to a wrapped object.
class EncryptionDecorator extends DataSourceDecorator is
    method writeData(data) is
        // 1. Encrypt passed data.
        // 2. Pass encrypted data to the wrappee's writeData
        // method.

    method readData():data is
        // 1. Get data from the wrappee's readData method.
        // 2. Try to decrypt it if it's encrypted.
        // 3. Return the result.

// You can wrap objects in several layers of decorators.
class CompressionDecorator extends DataSourceDecorator is
    method writeData(data) is
        // 1. Compress passed data.
        // 2. Pass compressed data to the wrappee's writeData
        // method.

    method readData():data is
        // 1. Get data from the wrappee's readData method.
        // 2. Try to decompress it if it's compressed.
        // 3. Return the result.


// Option 1. A simple example of a decorator assembly.
class Application is
    method dumbUsageExample() is
        source = new FileDataSource("somefile.dat")
        source.writeData(salaryRecords)
        // The target file has been written with plain data.

        source = new CompressionDecorator(source)
        source.writeData(salaryRecords)
        // The target file has been written with compressed
        // data.

        source = new EncryptionDecorator(source)
        // The source variable now contains this:
        // Encryption > Compression > FileDataSource
        source.writeData(salaryRecords)
        // The file has been written with compressed and
        // encrypted data.


// Option 2. Client code that uses an external data source.
// SalaryManager objects neither know nor care about data
// storage specifics. They work with a pre-configured data
// source received from the app configurator.
class SalaryManager is
    field source: DataSource

    constructor SalaryManager(source: DataSource) { ... }

    method load() is
        return source.readData()

    method save() is
        source.writeData(salaryRecords)
    // ...Other useful methods...


// The app can assemble different stacks of decorators at
// runtime, depending on the configuration or environment.
class ApplicationConfigurator is
    method configurationExample() is
        source = new FileDataSource("salary.dat")
        if (enabledEncryption)
            source = new EncryptionDecorator(source)
        if (enabledCompression)
            source = new CompressionDecorator(source)

        logger = new SalaryManager(source)
        salary = logger.load()
    // ...
```

**When to use:**
- Adding responsibilities to objects at runtime without affecting other objects
- When extension by subclassing is impractical (too many combinations)
- You want to add/remove features incrementally

**When NOT to use:**
- When the component's identity matters (decorators are wrappers, not the original object)
- When the stack of decorators would be too deep to reason about

**Related:** Adapter (changes an interface; Decorator adds to one), Composite (Decorator
is a Composite with one child), Strategy (changes the guts; Decorator changes the skin)

---

## Facade

**Intent:** Provide a unified, simplified interface to a set of interfaces in a subsystem.
Facade defines a higher-level interface that makes the subsystem easier to use.

**Participants:**
- **Facade** — knows which subsystem classes handle a request; delegates client requests
- **Subsystem classes** — implement subsystem functionality; handle work assigned by the Facade

**Key consideration:** Facade doesn't prevent clients from accessing subsystem classes directly
— it just offers a simpler route for common use cases. This is a feature, not a bug: advanced
clients can bypass the Facade when needed.

**Example:**
```
// These are some of the classes of a complex 3rd-party video
// conversion framework. We don't control that code, therefore
// can't simplify it.

class VideoFile
// ...

class OggCompressionCodec
// ...

class MPEG4CompressionCodec
// ...

class CodecFactory
// ...

class BitrateReader
// ...

class AudioMixer
// ...


// We create a facade class to hide the framework's complexity
// behind a simple interface. It's a trade-off between
// functionality and simplicity.
class VideoConverter is
    method convert(filename, format):File is
        file = new VideoFile(filename)
        sourceCodec = (new CodecFactory).extract(file)
        if (format == "mp4")
            destinationCodec = new MPEG4CompressionCodec()
        else
            destinationCodec = new OggCompressionCodec()
        buffer = BitrateReader.read(filename, sourceCodec)
        result = BitrateReader.convert(buffer, destinationCodec)
        result = (new AudioMixer()).fix(result)
        return new File(result)

// Application classes don't depend on a billion classes
// provided by the complex framework. Also, if you decide to
// switch frameworks, you only need to rewrite the facade class.
class Application is
    method main() is
        convertor = new VideoConverter()
        mp4 = convertor.convert("funny-cats-video.ogg", "mp4")
        mp4.save()

```

**When to use:**
- You want to provide a simple interface to a complex subsystem
- Many dependencies exist between clients and implementation classes
- You're layering subsystems — Facade defines an entry point to each layer

**When NOT to use:**
- When the subsystem is already simple enough
- When you're trying to *hide* the subsystem entirely (use encapsulation instead)

**Related:** Abstract Factory (can be used with Facade to provide an interface for creating
subsystem objects), Mediator (similar in that it centralizes interaction, but Mediator is for
colleague objects that know about each other; Facade is for simplifying a one-way interface),
Singleton (Facades are often Singletons)

---

## Flyweight

**Intent:** Use sharing to support large numbers of fine-grained objects efficiently.

**Participants:**
- **Flyweight** — declares interface for receiving and acting on extrinsic state
- **ConcreteFlyweight** — implements Flyweight; stores intrinsic (shared) state
- **UnsharedConcreteFlyweight** — not all Flyweight subclasses need to be shared
- **FlyweightFactory** — creates and manages Flyweight objects; ensures sharing
- **Client** — maintains extrinsic state; computes or stores it for Flyweight operations

**Intrinsic vs. extrinsic state:**
- **Intrinsic** — stored in the Flyweight; independent of context; shareable (e.g., a character's glyph)
- **Extrinsic** — depends on context; supplied by the client; not stored in the Flyweight
  (e.g., a character's position on screen)

**Example:**
```
// The flyweight class contains a portion of the state of a
// tree. These fields store values that are unique for each
// particular tree. For instance, you won't find here the tree
// coordinates. But the texture and colors shared between many
// trees are here. Since this data is usually BIG, you'd waste a
// lot of memory by keeping it in each tree object. Instead, we
// can extract texture, color and other repeating data into a
// separate object which lots of individual tree objects can
// reference.
class TreeType is
    field name
    field color
    field texture
    constructor TreeType(name, color, texture) { ... }
    method draw(canvas, x, y) is
        // 1. Create a bitmap of a given type, color & texture.
        // 2. Draw the bitmap on the canvas at X and Y coords.

// Flyweight factory decides whether to re-use existing
// flyweight or to create a new object.
class TreeFactory is
    static field treeTypes: collection of tree types
    static method getTreeType(name, color, texture) is
        type = treeTypes.find(name, color, texture)
        if (type == null)
            type = new TreeType(name, color, texture)
            treeTypes.add(type)
        return type

// The contextual object contains the extrinsic part of the tree
// state. An application can create billions of these since they
// are pretty small: just two integer coordinates and one
// reference field.
class Tree is
    field x,y
    field type: TreeType
    constructor Tree(x, y, type) { ... }
    method draw(canvas) is
        type.draw(canvas, this.x, this.y)

// The Tree and the Forest classes are the flyweight's clients.
// You can merge them if you don't plan to develop the Tree
// class any further.
class Forest is
    field trees: collection of Trees

    method plantTree(x, y, name, color, texture) is
        type = TreeFactory.getTreeType(name, color, texture)
        tree = new Tree(x, y, type)
        trees.add(tree)

    method draw(canvas) is
        foreach (tree in trees) do
            tree.draw(canvas)
```

**When to use:**
- An application uses a large number of objects
- Storage costs are high because of object quantity
- Most object state can be made extrinsic

**When NOT to use:**
- When the savings in memory don't outweigh the overhead of managing shared/extrinsic state
- When objects are few in number or vary widely in state

**Related:** Composite (Flyweight nodes are often used in Composite trees), State and
Strategy (can be implemented as Flyweights)

---

## Proxy

**Intent:** Provide a surrogate or placeholder for another object to control access to it.

**Participants:**
- **Subject** — defines the common interface for RealSubject and Proxy
- **RealSubject** — the real object the Proxy represents
- **Proxy** — maintains a reference to RealSubject; controls access; may create/delete it

**Common proxy types:**
- **Remote Proxy** — represents an object in a different address space
- **Virtual Proxy** — creates expensive objects on demand (lazy initialization)
- **Protection Proxy** — controls access rights to the RealSubject
- **Caching Proxy** — caches expensive results of RealSubject operations
- **Logging/Monitoring Proxy** — records calls to the RealSubject

**Example:**
```
// The interface of a remote service.
interface ThirdPartyYouTubeLib is
    method listVideos()
    method getVideoInfo(id)
    method downloadVideo(id)

// The concrete implementation of a service connector. Methods
// of this class can request information from YouTube. The speed
// of the request depends on a user's internet connection as
// well as YouTube's. The application will slow down if a lot of
// requests are fired at the same time, even if they all request
// the same information.
class ThirdPartyYouTubeClass implements ThirdPartyYouTubeLib is
    method listVideos() is
        // Send an API request to YouTube.

    method getVideoInfo(id) is
        // Get metadata about some video.

    method downloadVideo(id) is
        // Download a video file from YouTube.

// To save some bandwidth, we can cache request results and keep
// them for some time. But it may be impossible to put such code
// directly into the service class. For example, it could have
// been provided as part of a third party library and/or defined
// as `final`. That's why we put the caching code into a new
// proxy class which implements the same interface as the
// service class. It delegates to the service object only when
// the real requests have to be sent.
class CachedYouTubeClass implements ThirdPartyYouTubeLib is
    private field service: ThirdPartyYouTubeLib
    private field listCache, videoCache
    field needReset

    constructor CachedYouTubeClass(service: ThirdPartyYouTubeLib) is
        this.service = service

    method listVideos() is
        if (listCache == null || needReset)
            listCache = service.listVideos()
        return listCache

    method getVideoInfo(id) is
        if (videoCache == null || needReset)
            videoCache = service.getVideoInfo(id)
        return videoCache

    method downloadVideo(id) is
        if (!downloadExists(id) || needReset)
            service.downloadVideo(id)

// The GUI class, which used to work directly with a service
// object, stays unchanged as long as it works with the service
// object through an interface. We can safely pass a proxy
// object instead of a real service object since they both
// implement the same interface.
class YouTubeManager is
    protected field service: ThirdPartyYouTubeLib

    constructor YouTubeManager(service: ThirdPartyYouTubeLib) is
        this.service = service

    method renderVideoPage(id) is
        info = service.getVideoInfo(id)
        // Render the video page.

    method renderListPanel() is
        list = service.listVideos()
        // Render the list of video thumbnails.

    method reactOnUserInput() is
        renderVideoPage()
        renderListPanel()

// The application can configure proxies on the fly.
class Application is
    method init() is
        aYouTubeService = new ThirdPartyYouTubeClass()
        aYouTubeProxy = new CachedYouTubeClass(aYouTubeService)
        manager = new YouTubeManager(aYouTubeProxy)
        manager.reactOnUserInput()
```

**When to use:**
- You need a more versatile or sophisticated reference to an object than a plain pointer
- Any of the proxy types above applies to your situation

**When NOT to use:**
- When the indirection adds latency/complexity without benefit
- When a simpler pattern (e.g., Decorator) would accomplish the same thing

**Related:** Adapter (provides a different interface; Proxy provides the same interface),
Decorator (adds behavior; Proxy controls access), Facade (simplifies; Proxy has the same interface)
