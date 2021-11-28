Read this first: [Distributed map in EUTXO model](https://mlabs.slab.com/posts/h5pymk59)

Often there is a need to traverse a distributed map. While traversal is in progress the values associated with the keys may be changed. The problem is analogue to accessing a complex data structure in multi threaded environment. Presence of multiple writers and readers results in inconsistent view on a data structure. There are multiple approaches to the problem. Let&#39;s discover solutions to the problem of traversing a distributed map.

## Locking

The most obvious one is introducing a &#39;lock&#39; flag on utxo datums. That&#39;s an analog of a mutex. The flag is set on &#39;global utxo&#39; associated with data structure when traversal is in progress and cleared when the process is finished. When the flag is set any transaction that alters a distributed map in any way is expected to fail. In this approach &#39;global utxo&#39; must be consumed in every transaction that alters values in a distributed map. That means that the throughput for modifying existing entries will be much lower than in vanilla distributed map.

## Snapshots

The other approach is lock-free. The notion of snapshot comes to the rescue. The idea is to add new piece of information to &#39;global&#39; and &#39;entry&#39; utxos related to snapshot versioning. Snapshot version is an integer that starts with 0 and that gets incremented every time user triggers a snapshot creation. The process of making a snapshot appears to be atomic although it consists of may transactions. It is initiated by bumping snapshot version number in &#39;global utxo&#39;. When &#39;entry utxo&#39; is consumed in a transaction its version number is compared to a version number in &#39;global utxo&#39;.

If those versions differ the transaction produces two &#39;entry utxos&#39; at the output (instead of just one):

- snapshot &#39;entry utxo&#39; that contains old data and old version number. That snapshot &#39;entry utxo&#39; becomes immutable - it can be consumed only for read-only purposes
- &#39;entry utxo&#39; with a new version number and, possibly, an updated value. It&#39;s mutable and can be seen as &#39;live&#39; &#39;entry utxo&#39;

Creation of snapshot &#39;entry utxos&#39; is done lazily here. Of course it can be forced.

In this approach &#39;global utxo&#39; must be consumed in every transaction that alters values in a distributed map as well.

## Comparison

Let&#39;s compare these two approaches:

|  | Locking | Snapshots | &#39;Vanilla&#39; map |
| --- | --- | --- | --- |
| reading &#39;entry utxo&#39; | high throughput | high throughput | high throughput |
| modifying &#39;entry utxo&#39; | low throughput | low throughput | high throughput |
| can alter map while traversal in progress | no | yes | no |
| maintains history | no | yes | no |
| traversal reproducible | no | yes | no |

So it seems that the price that we have to pay for consistency is low throughput of &#39;entry utxo&#39; modification. Snapshot approach has the advantage of maintaining history and allowing for map modification when traversal is in progress. Snapshots may be reused and traversed many times (reproducibility) while locking approach uses &#39;live&#39; version of a map every time it&#39;s traversed. The other advantage of snapshots is that you can make a snapshot of many different maps in the same transaction. That boils down to bumping version number in &#39;global utxos&#39; of many maps at once in the same transaction.

Snapshot approach is clearly a winner.

Low map modification throughput can be mitigated by load balancing techniques.
