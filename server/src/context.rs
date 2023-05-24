use std::{collections::HashMap, sync::Arc};

use futures_channel::mpsc::{self, TrySendError, UnboundedReceiver, UnboundedSender};
use tokio::sync::RwLock;

use crate::frame::ServerFrame;

#[derive(Debug, Clone)]
struct Context {
    users: UserPool,
}

type Tx = UnboundedSender<ServerFrame>;
type Rx = UnboundedReceiver<ServerFrame>;

#[derive(Default, Debug, Clone)]
struct UserPool(Arc<RwLock<HashMap<String, Tx>>>);

impl UserPool {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn register_user(&self, handle: impl Into<String>) -> Option<UserGuard> {
        let handle = handle.into();
        let mut w_lock = self.0.write().await;
        if w_lock.contains_key(&handle) {
            return None;
        }
        let (tx, rx) = mpsc::unbounded();
        w_lock.insert(handle.clone(), tx.clone());
        Some(UserGuard {
            handle,
            pool: self,
            tx,
            rx,
        })
    }

    pub async fn contains(&self, handle: &str) -> bool {
        self.0.read().await.contains_key(handle)
    }

    pub async fn broadcast(&self, frame: ServerFrame) {
        for tx in self.0.read().await.values() {
            let _ = tx.unbounded_send(frame.clone());
        }
    }

    pub async fn broadcast_except(&self, handle: &str, frame: ServerFrame) {
        for (_, tx) in self
            .0
            .read()
            .await
            .iter()
            .filter(|(h, _)| h.as_str() != handle)
        {
            let _ = tx.unbounded_send(frame.clone());
        }
    }

    pub fn remove_user_sync(&self, handle: String) {
        if let Ok(mut w_lock) = self.0.try_write() {
            // remove the thing immediately if possible
            w_lock.remove(&handle);
        } else {
            // otherwise use tokio to schedule removal
            let data = Arc::clone(&self.0);
            tokio::spawn(async move { data.write().await.remove(&handle) });
        }
    }
}

struct UserGuard<'p> {
    handle: String,
    pool: &'p UserPool,
    tx: Tx,
    rx: Rx,
}

impl UserGuard<'_> {
    fn message(&self, frame: ServerFrame) -> Result<(), TrySendError<ServerFrame>> {
        self.tx.unbounded_send(frame)?;

        Ok(())
    }
}

impl Drop for UserGuard<'_> {
    fn drop(&mut self) {
        let handle = std::mem::take(&mut self.handle);
        self.pool.remove_user_sync(handle);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn register_user() {
        let pool = UserPool::new();
        let _bob = pool.register_user("bob").await.unwrap();
        assert!(pool.contains("bob").await);
    }

    #[tokio::test]
    async fn nonexistent_user() {
        let pool = UserPool::new();
        let _bob = pool.register_user("bob").await.unwrap();
        assert!(!pool.contains("tom").await);
    }

    #[tokio::test]
    async fn unregister_user() {
        let pool = UserPool::new();
        {
            let _bob = pool.register_user("bob").await.unwrap();
        }
        assert!(!pool.contains("bob").await);
    }

    #[tokio::test]
    async fn broadcast() {
        let pool = UserPool::new();
        let mut anne = pool.register_user("anne").await.unwrap();
        let mut bob = pool.register_user("bob").await.unwrap();

        let frame = ServerFrame::Broadcast {
            sender: "system".to_string(),
            msg: "hi".to_string(),
        };
        pool.broadcast(frame.clone()).await;

        assert_eq!(frame, anne.rx.try_next().unwrap().unwrap());
        assert_eq!(frame, bob.rx.try_next().unwrap().unwrap());
    }

    #[tokio::test]
    async fn broadcast_except() {
        let pool = UserPool::new();
        let mut anne = pool.register_user("anne").await.unwrap();
        let mut bob = pool.register_user("bob").await.unwrap();

        let frame = ServerFrame::Broadcast {
            sender: "system".to_string(),
            msg: "hi".to_string(),
        };
        pool.broadcast_except("bob", frame.clone()).await;

        assert_eq!(frame, anne.rx.try_next().unwrap().unwrap());
        assert!(bob.rx.try_next().is_err());
    }

    #[tokio::test]
    async fn message() {
        let pool = UserPool::new();
        let mut anne = pool.register_user("anne").await.unwrap();

        let frame = ServerFrame::Okay(42);
        anne.message(frame.clone()).unwrap();

        assert_eq!(frame, anne.rx.try_next().unwrap().unwrap());
    }
}
