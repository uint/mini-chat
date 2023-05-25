use std::sync::Arc;

use dashmap::{mapref::multiple::RefMulti, DashMap};
use futures_channel::mpsc::{self, TrySendError, UnboundedReceiver, UnboundedSender};

use crate::frame::ServerFrame;

#[derive(Default, Debug, Clone)]
pub struct Context {
    users: UserPool,
}

impl Context {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn users(&self) -> &UserPool {
        &self.users
    }
}

type Tx = UnboundedSender<ServerFrame>;
type Rx = UnboundedReceiver<ServerFrame>;

#[derive(Default, Debug, Clone)]
pub struct UserPool(Arc<DashMap<String, Tx>>);

impl UserPool {
    pub fn register_user_with_callback<F>(
        &self,
        handle: impl Into<String>,
        on_drop: F,
    ) -> Option<UserGuard<'_, F>>
    where
        F: Fn(&str, &UserPool),
    {
        let handle = handle.into();
        if self.0.contains_key(&handle) {
            return None;
        }
        let (tx, rx) = mpsc::unbounded();
        self.0.insert(handle.clone(), tx.clone());
        Some(UserGuard {
            handle,
            pool: self,
            tx,
            rx: Some(rx),
            on_drop,
        })
    }

    /// Don't hold this iterator or the guards it produces across await points!
    pub fn users(&self) -> Users<'_> {
        Users {
            iter: self.0.iter(),
        }
    }

    pub fn broadcast(&self, frame: ServerFrame) {
        for r in self.0.iter() {
            let tx = r.value();
            let _ = tx.unbounded_send(frame.clone());
        }
    }

    pub fn broadcast_except(&self, handle: &str, frame: ServerFrame) {
        for r in self.0.iter().filter(|r| r.key() != handle) {
            let tx = r.value();
            let _ = tx.unbounded_send(frame.clone());
        }
    }

    fn remove_user(&self, handle: &str) {
        self.0.remove(handle);
    }
}

pub struct Users<'a> {
    iter: dashmap::iter::Iter<'a, String, Tx>,
}

impl<'a> Iterator for Users<'a> {
    type Item = UserHandleRef<'a>;

    fn next(&mut self) -> Option<Self::Item> {
        self.iter.next().map(UserHandleRef)
    }
}

pub struct UserHandleRef<'a>(RefMulti<'a, String, Tx>);

impl std::ops::Deref for UserHandleRef<'_> {
    type Target = str;

    fn deref(&self) -> &Self::Target {
        self.0.key()
    }
}

impl std::cmp::PartialEq for UserHandleRef<'_> {
    fn eq(&self, other: &Self) -> bool {
        self.0.key() == other.0.key()
    }
}

impl Eq for UserHandleRef<'_> {}

impl std::cmp::PartialEq<&str> for UserHandleRef<'_> {
    fn eq(&self, other: &&str) -> bool {
        self.0.key() == other
    }
}

impl std::cmp::PartialEq<UserHandleRef<'_>> for &str {
    fn eq(&self, other: &UserHandleRef) -> bool {
        self == other.0.key()
    }
}

impl std::hash::Hash for UserHandleRef<'_> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.0.key().hash(state);
    }
}

impl std::fmt::Debug for UserHandleRef<'_> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_tuple("UserHandleRef").field(&self.0.key()).finish()
    }
}

impl From<UserHandleRef<'_>> for String {
    fn from(value: UserHandleRef<'_>) -> Self {
        value.0.key().to_string()
    }
}

pub struct UserGuard<'p, F>
where
    F: Fn(&str, &UserPool),
{
    handle: String,
    pool: &'p UserPool,
    tx: Tx,
    rx: Option<Rx>,
    on_drop: F,
}

impl<F> UserGuard<'_, F>
where
    F: Fn(&str, &UserPool),
{
    pub fn send(&self, frame: ServerFrame) -> Result<(), TrySendError<ServerFrame>> {
        self.tx.unbounded_send(frame)?;

        Ok(())
    }

    pub fn handle(&self) -> &str {
        &self.handle
    }

    pub fn take_rx(&mut self) -> Option<Rx> {
        self.rx.take()
    }
}

impl<F> Drop for UserGuard<'_, F>
where
    F: Fn(&str, &UserPool),
{
    fn drop(&mut self) {
        self.pool.remove_user(&self.handle);
        (self.on_drop)(self.handle(), self.pool);
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashSet;

    use dashmap::try_result::TryResult;
    use futures_util::StreamExt as _;

    use super::*;

    impl UserPool {
        pub fn new() -> Self {
            Self::default()
        }

        pub fn register_user(
            &self,
            handle: impl Into<String>,
        ) -> Option<UserGuard<'_, impl Fn(&str, &UserPool)>> {
            self.register_user_with_callback(handle, |_, _| {})
        }

        pub fn contains(&self, handle: &str) -> bool {
            self.0.contains_key(handle)
        }
    }

    #[test]
    fn register_user() {
        let pool = UserPool::new();
        let _bob = pool.register_user("bob").unwrap();
        assert!(pool.contains("bob"));
    }

    #[test]
    fn nonexistent_user() {
        let pool = UserPool::new();
        let _bob = pool.register_user("bob").unwrap();
        assert!(!pool.contains("tom"));
    }

    #[test]
    fn unregister_user() {
        let pool = UserPool::new();
        {
            let _bob = pool.register_user("bob").unwrap();
        }
        assert!(!pool.contains("bob"));
    }

    #[test]
    fn iterate_users() {
        let pool = UserPool::new();
        let _anne = pool.register_user("anne").unwrap();
        let _bob = pool.register_user("bob").unwrap();

        let users: Vec<_> = pool.users().map(String::from).collect();

        assert_eq!(
            users.iter().map(String::as_str).collect::<HashSet<_>>(),
            HashSet::<&str>::from(["anne", "bob"])
        );
    }

    #[test]
    fn iterate_users_safety() {
        let pool = UserPool::new();
        let _anne = pool.register_user("anne").unwrap();
        let _bob = pool.register_user("bob").unwrap();
        let _dudeson = pool.register_user("dudeson").unwrap();

        let _users = pool
            .users()
            .filter(|u| *u != "dudeson") // this will drop the guard for "dudeson"
            .collect::<HashSet<_>>(); // we're only holding guards for "anne" and "bob"

        assert!(matches!(pool.0.try_get_mut("anne"), TryResult::Locked));
        assert!(matches!(pool.0.try_get_mut("bob"), TryResult::Locked));
        assert!(matches!(pool.0.try_get_mut("claire"), TryResult::Absent));
        assert!(matches!(
            pool.0.try_get_mut("dudeson"),
            TryResult::Present(_)
        ));
    }

    #[tokio::test]
    async fn broadcast() {
        let pool = UserPool::new();
        let mut anne = pool.register_user("anne").unwrap();
        let mut bob = pool.register_user("bob").unwrap();

        let frame = ServerFrame::Broadcast {
            sender: "system".to_string(),
            msg: "hi".to_string(),
        };
        pool.broadcast(frame.clone());

        assert_eq!(frame, anne.take_rx().unwrap().next().await.unwrap());
        assert_eq!(frame, bob.take_rx().unwrap().next().await.unwrap());
    }

    #[tokio::test]
    async fn broadcast_except() {
        let pool = UserPool::new();
        let mut anne = pool.register_user("anne").unwrap();
        let mut bob = pool.register_user("bob").unwrap();

        let frame = ServerFrame::Broadcast {
            sender: "system".to_string(),
            msg: "hi".to_string(),
        };
        pool.broadcast_except("bob", frame.clone());

        assert_eq!(frame, anne.take_rx().unwrap().next().await.unwrap());
        assert!(bob.rx.as_mut().unwrap().try_next().is_err());
    }

    #[tokio::test]
    async fn message() {
        let pool = UserPool::new();
        let mut anne = pool.register_user("anne").unwrap();

        let frame = ServerFrame::Okay(42);
        anne.send(frame.clone()).unwrap();

        assert_eq!(frame, anne.take_rx().unwrap().next().await.unwrap());
    }

    #[tokio::test]
    async fn user_guard_stream() {
        let pool = UserPool::new();
        let mut anne = pool.register_user("anne").unwrap();

        let login_frame = ServerFrame::Login("bob".to_string());
        let okay_frame = ServerFrame::Okay(42);

        anne.send(login_frame.clone()).unwrap();
        anne.send(okay_frame.clone()).unwrap();

        let mut rx = anne.take_rx().unwrap();

        assert_eq!(rx.next().await.unwrap(), login_frame);
        assert_eq!(rx.next().await.unwrap(), okay_frame);
    }
}
