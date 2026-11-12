"""
Minimo Brain Suite - ONNX Cross-Encoder & Hybrid RRF Reranker
Provides high-precision semantic reranking on CPU with graceful RRF fallback.
"""

import os
import numpy as np
from typing import List, Dict, Any, Optional

MODEL_DIRS = [
    os.path.expanduser("~/.local/share/quickshell/models/ms-marco-MiniLM-L-6-v2"),
    os.path.expanduser("~/.local/share/quickshell/models/bge-reranker-base"),
    os.path.expanduser("~/.local/share/quickshell/models/bge-reranker-small"),
    os.path.expanduser("~/.local/share/quickshell/models/reranker"),
]

class ONNXCrossEncoder:
    """
    Ultra-lightweight ONNX Cross-Encoder for CPU Workstations.
    Auto-detects ms-marco-MiniLM-L-6-v2, bge-reranker-base, or generic reranker weights.
    Gracefully falls back to Reciprocal Rank Fusion (RRF) if weights are absent.
    """
    def __init__(self, model_dirs: Optional[List[str]] = None):
        self.model_dirs = model_dirs or MODEL_DIRS
        self.active_dir = None
        self.session = None
        self.tokenizer = None
        self.is_ready = False
        self._load_model()

    def _load_model(self):
        try:
            import onnxruntime as ort
            from tokenizers import Tokenizer

            for d in self.model_dirs:
                if not os.path.isdir(d):
                    continue
                model_candidates = [
                    os.path.join(d, "model.onnx"),
                    os.path.join(d, "model_quantized.onnx"),
                    os.path.join(d, "model_int8.onnx")
                ]
                model_path = next((p for p in model_candidates if os.path.isfile(p)), None)
                tok_path = os.path.join(d, "tokenizer.json")

                if model_path and os.path.isfile(tok_path):
                    opts = ort.SessionOptions()
                    opts.intra_op_num_threads = 2
                    opts.inter_op_num_threads = 1
                    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
                    self.session = ort.InferenceSession(model_path, opts, providers=["CPUExecutionProvider"])
                    self.tokenizer = Tokenizer.from_file(tok_path)
                    self.tokenizer.enable_truncation(max_length=512)
                    self.tokenizer.enable_padding(direction="right", pad_id=0, pad_token="[PAD]")
                    self.active_dir = d
                    self.is_ready = True
                    break
        except Exception:
            self.is_ready = False

    def rerank(self, query: str, candidates: List[Dict[str, Any]], top_k: int = 4, threshold: float = 0.25) -> List[Dict[str, Any]]:
        """
        Reranks retrieved candidate chunks.
        If ONNX is available: evaluates cross-attention logits with sigmoid probability.
        If ONNX is absent: sorts by blended RRF score.
        """
        if not candidates:
            return []

        # Fast path: Single candidate doesn't need cross-evaluation
        if len(candidates) == 1:
            return candidates

        if self.is_ready and self.session and self.tokenizer:
            try:
                pairs = [(query, c.get("content", "")[:1200]) for c in candidates]
                encodings = self.tokenizer.encode_batch(pairs)

                input_ids = np.array([e.ids for e in encodings], dtype=np.int64)
                attention_mask = np.array([e.attention_mask for e in encodings], dtype=np.int64)

                inputs = {
                    "input_ids": input_ids,
                    "attention_mask": attention_mask
                }
                # Check if model requires token_type_ids
                input_names = [inp.name for inp in self.session.get_inputs()]
                if "token_type_ids" in input_names:
                    token_type_ids = np.array([e.type_ids for e in encodings], dtype=np.int64)
                    inputs["token_type_ids"] = token_type_ids

                outputs = self.session.run(None, inputs)[0]
                logits = outputs.flatten()

                # Sigmoid activation to convert logits to 0.0 - 1.0 probability
                scores = 1.0 / (1.0 + np.exp(-logits))

                for c, score in zip(candidates, scores):
                    c["rerank_score"] = float(score)

                # Filter and rank candidates
                ranked = sorted(candidates, key=lambda x: x.get("rerank_score", 0.0), reverse=True)
                
                # Zero-Hallucination Gate: If top-1 candidate is irrelevant (prob < threshold), abort
                if not ranked or ranked[0].get("rerank_score", 0.0) < threshold:
                    return []

                # Dynamic Context Pruning (Elbow method):
                # Cut off noisy tail chunks if there is a steep score drop
                pruned = [ranked[0]]
                for i in range(min(len(ranked) - 1, top_k - 1)):
                    s_curr = ranked[i].get("rerank_score", 0.0)
                    s_next = ranked[i + 1].get("rerank_score", 0.0)
                    if s_next < threshold:
                        break
                    # If score drops by more than 70% from current substantive chunk, cut the tail
                    if s_curr > 0.30 and s_next < s_curr * 0.30:
                        break
                    pruned.append(ranked[i + 1])

                return pruned[:top_k]
            except Exception:
                pass

        # Fallback: Sort by RRF score or blended bm25/vector score
        return sorted(candidates, key=lambda x: x.get("score", x.get("bm25_score", 0.0)), reverse=True)[:top_k]

def reciprocal_rank_fusion(bm25_rank_list: List[int], vector_rank_list: List[int], k: int = 60) -> List[int]:
    """Pure arithmetic reciprocal rank fusion (0 ms latency)."""
    scores = {}
    for rank, doc_id in enumerate(bm25_rank_list):
        scores[doc_id] = scores.get(doc_id, 0.0) + 1.0 / (k + rank + 1)
    for rank, doc_id in enumerate(vector_rank_list):
        scores[doc_id] = scores.get(doc_id, 0.0) + 1.0 / (k + rank + 1)
    return sorted(scores.keys(), key=lambda x: scores[x], reverse=True)

# Global singleton
_RERANKER_INSTANCE = None

def get_reranker() -> ONNXCrossEncoder:
    global _RERANKER_INSTANCE
    if _RERANKER_INSTANCE is None:
        _RERANKER_INSTANCE = ONNXCrossEncoder()
    return _RERANKER_INSTANCE
