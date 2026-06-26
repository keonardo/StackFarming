using Godot;
using System;
using System.Collections.Generic;

namespace StackFarming
{
    public partial class BaseCard : Area2D
    {
        [Export] public CardRole Role { get; set; }
        [Export] public CardType Type { get; set; }
        [Export] public string CardName { get; set; } = "Unnamed Card";
        [Export] public bool ShowDebugInfo { get; set; } = true;

        // 双数值体系
        [Export]
        public float ValueA
        {
            get => _valueA;
            set
            {
                _valueA = value;
                if (Role == CardRole.Creature && _valueA <= 0f && !_isDying)
                {
                    _isDying = true;
                    OnHealthZero();
                }
            }
        }
        private float _valueA;

        [Export] public float ValueB { get; set; }

        private bool _isDying = false;

        // 堆叠链条指针
        public BaseCard StackParent { get; protected set; }
        public BaseCard StackChild { get; protected set; }

        // 堆叠状态改变信号
        [Signal]
        public delegate void StackParentChangedEventHandler(BaseCard oldParent, BaseCard newParent);
        [Signal]
        public delegate void StackChildChangedEventHandler(BaseCard oldChild, BaseCard newChild);
        [Signal]
        public delegate void OnCardStackedEventHandler(BaseCard stackedCard, BaseCard targetCard);
        [Signal]
        public delegate void HealthZeroEventHandler(BaseCard card);

        #region 语义化属性映射
        
        // 生物卡: ValueA = Health, ValueB = Progress
        public float Health
        {
            get => Role == CardRole.Creature ? ValueA : 0f;
            set { if (Role == CardRole.Creature) ValueA = Mathf.Max(0f, value); }
        }

        public float Progress
        {
            get => Role == CardRole.Creature ? ValueB : 0f;
            set { if (Role == CardRole.Creature) ValueB = Mathf.Max(0f, value); }
        }

        // 资源卡: ValueA = Intensity, ValueB = Duration
        public float Intensity
        {
            get => Role == CardRole.Resource ? ValueA : 0f;
            set { if (Role == CardRole.Resource) ValueA = value; }
        }

        public float Duration
        {
            get => Role == CardRole.Resource ? ValueB : 0f;
            set { if (Role == CardRole.Resource) ValueB = Mathf.Max(0f, value); }
        }

        // 容器卡: ValueA = Capacity, ValueB = Moisture
        public float Capacity
        {
            get => Role == CardRole.Container ? ValueA : 0f;
            set { if (Role == CardRole.Container) ValueA = Mathf.Max(0f, value); }
        }

        public float Moisture
        {
            get => Role == CardRole.Container ? ValueB : 0f;
            set { if (Role == CardRole.Container) ValueB = Mathf.Max(0f, value); }
        }

        #endregion

        protected bool _isDragging = false;
        private Vector2 _dragOffset = Vector2.Zero;

        public override void _Ready()
        {
            // 开启鼠标拾取，以接收输入事件
            InputPickable = true;

            // 启动时自动检测重叠并对齐堆叠
            CallDeferred(MethodName.InitializeStartingStack);
        }

        private void InitializeStartingStack()
        {
            if (StackParent == null)
            {
                BaseCard target = FindBestStackTarget();
                if (target != null)
                {
                    StackOn(target);
                }
            }
        }

        public override void _Process(double delta)
        {
            if (_isDragging)
            {
                GlobalPosition = GetGlobalMousePosition() - _dragOffset;
            }
            else if (StackParent != null)
            {
                // 紧随父卡牌位置，平滑插值吸附，配合堆叠偏移 (0, 35)
                Vector2 targetPos = StackParent.GlobalPosition + new Vector2(0, 35);
                GlobalPosition = GlobalPosition.Lerp(targetPos, (float)delta * 18f);
                ZIndex = StackParent.ZIndex + 1;
            }
            else
            {
                ZIndex = 0;
                // 物理排斥排挤，避免独立卡牌堆叠穿模
                ProcessMutualPushing((float)delta);
            }

            // 更新子卡的 Z 排序，使其显示在更上层
            if (StackChild != null)
            {
                StackChild.ZIndex = ZIndex + 1;
            }

            // 资源卡持续时间倒计时
            if (Role == CardRole.Resource)
            {
                Duration -= (float)delta;
                if (Duration <= 0f)
                {
                    GD.Print($"[Resource] {CardName} duration expired. Removing.");
                    UnstackAndRemove();
                    return;
                }
            }

            // 动态数据刷新 UI 渲染
            UpdateVisuals();
        }

        /// <summary>
        /// 物理推动排斥逻辑：推动重叠的独立卡牌或卡牌堆，保持布局整洁
        /// </summary>
        private void ProcessMutualPushing(float delta)
        {
            // 只有未被拖拽且是堆叠根部（最底层）的卡牌，才作为物理推动主体进行位移
            if (_isDragging || StackParent != null) return;

            foreach (Area2D area in GetOverlappingAreas())
            {
                if (area is BaseCard otherCard && GodotObject.IsInstanceValid(otherCard))
                {
                    // 获取对方所属的堆叠根卡
                    BaseCard otherRoot = otherCard.GetStackRoot();
                    
                    // 如果对方与自己不属于同一个堆叠链，且对方没有在被拖拽
                    if (otherRoot != this && !otherRoot._isDragging)
                    {
                        Vector2 diff = GlobalPosition - otherRoot.GlobalPosition;
                        float dist = diff.Length();
                        
                        // 设定推动排斥半径 (卡牌尺寸约80x100，排斥阈值设为95f)
                        float pushThreshold = 95f;
                        
                        if (dist < pushThreshold)
                        {
                            Vector2 pushDir;
                            if (dist < 0.1f)
                            {
                                // 完美重合时，随机产生推力方向
                                pushDir = new Vector2((float)GD.RandRange(-1, 1), (float)GD.RandRange(-1, 1)).Normalized();
                                dist = 1.0f;
                            }
                            else
                            {
                                pushDir = diff / dist;
                            }

                            // 线性渐变排斥力：距离越近力越大，平滑渐出
                            float force = (pushThreshold - dist) * 12f;
                            
                            // 顺着推力方向平滑发生位移
                            GlobalPosition += pushDir * force * delta;
                        }
                    }
                }
            }
        }

        private void UpdateVisuals()
        {
            var nameLabel = GetNodeOrNull<Label>("Panel/NameLabel");
            if (nameLabel != null)
            {
                nameLabel.Text = CardName;
            }

            // 开发模式下隐藏调试信息时，隐藏数值面板
            var panel = GetNodeOrNull<Control>("Panel");
            if (panel != null)
            {
                panel.Visible = ShowDebugInfo;
            }
            if (!ShowDebugInfo) return;

            var valALabel = GetNodeOrNull<Label>("Panel/ValueALabel");
            var valBLabel = GetNodeOrNull<Label>("Panel/ValueBLabel");
            var progress = GetNodeOrNull<ProgressBar>("Panel/ProgressBar");

            if (Role == CardRole.Creature)
            {
                if (valALabel != null) valALabel.Text = $"HP: {Health:F0}";
                if (valBLabel != null) valBLabel.Text = $"Prog: {Progress:F0}%";
                if (progress != null)
                {
                    progress.Visible = true;
                    progress.Value = Progress;
                }
            }
            else if (Role == CardRole.Resource)
            {
                if (valALabel != null) valALabel.Text = $"Int: {Intensity:F1}";
                if (valBLabel != null) valBLabel.Text = $"Dur: {Duration:F0}s";
                if (progress != null) progress.Visible = false;
            }
            else if (Role == CardRole.Container)
            {
                bool irrigated = false;
                if (this is ContainerCard container)
                {
                    irrigated = container.IsIrrigated;
                }
                if (valALabel != null) valALabel.Text = $"Cap: {Capacity:F0}";
                if (valBLabel != null) valBLabel.Text = $"Moist: {Moisture:F0} {(irrigated ? "(Irr)" : "(Dry)")}";
                if (progress != null) progress.Visible = false;
            }
        }

        public override void _InputEvent(Viewport viewport, InputEvent @event, int shapeIdx)
        {
            if (@event is InputEventMouseButton mouseBtn && mouseBtn.ButtonIndex == MouseButton.Left)
            {
                if (mouseBtn.Pressed)
                {
                    // 开始拖拽
                    _isDragging = true;
                    _dragOffset = GetGlobalMousePosition() - GlobalPosition;
                    ZIndex = 100;

                    // 拖拽时如果已有父级，解除堆叠关系
                    if (StackParent != null)
                    {
                        Unstack();
                    }

                    GetViewport().SetInputAsHandled();
                }
            }
        }

        public override void _Input(InputEvent @event)
        {
            if (_isDragging && @event is InputEventMouseButton mouseBtn && mouseBtn.ButtonIndex == MouseButton.Left && !mouseBtn.Pressed)
            {
                // 停止拖拽
                _isDragging = false;
                ZIndex = 0;

                // 寻找最适合堆叠的卡牌
                BaseCard target = FindBestStackTarget();
                if (target != null)
                {
                    StackOn(target);
                }

                GetViewport().SetInputAsHandled();
            }
        }

        private BaseCard FindBestStackTarget()
        {
            BaseCard bestTarget = null;
            float minDistance = 100f; // 判定吸附堆叠的最大像素半径

            foreach (Area2D area in GetOverlappingAreas())
            {
                if (area is BaseCard card && card != this && GodotObject.IsInstanceValid(card))
                {
                    // 害虫卡不参与堆叠
                    if (card.Type == CardType.Pest || Type == CardType.Pest) continue;

                    // 不能堆叠在已经有其他子卡的卡牌上
                    if (card.StackChild != null && card.StackChild != this) continue;

                    // 环形堆叠防御（不能堆叠在自己子卡链条的卡牌上）
                    if (IsInOurStackChain(card)) continue;

                    float dist = GlobalPosition.DistanceTo(card.GlobalPosition);
                    if (dist < minDistance)
                    {
                        minDistance = dist;
                        bestTarget = card;
                    }
                }
            }

            return bestTarget;
        }

        private bool IsInOurStackChain(BaseCard card)
        {
            BaseCard current = this;
            while (current != null)
            {
                if (current == card) return true;
                current = current.StackChild;
            }
            return false;
        }

        /// <summary>
        /// 堆叠在目标卡牌上方
        /// </summary>
        public virtual void StackOn(BaseCard newParent)
        {
            if (StackParent == newParent) return;

            BaseCard oldParent = StackParent;
            if (StackParent != null)
            {
                StackParent.StackChild = null;
                StackParent.EmitSignal(SignalName.StackChildChanged, this, default(Variant));
            }

            StackParent = newParent;
            if (newParent != null)
            {
                // 断开新父卡原有的子卡连接
                if (newParent.StackChild != null && newParent.StackChild != this)
                {
                    newParent.StackChild.Unstack();
                }
                newParent.StackChild = this;
                newParent.EmitSignal(SignalName.StackChildChanged, default(Variant), this);
                newParent.EmitSignal(SignalName.OnCardStacked, this, newParent);

                // 瞬间物理贴合对齐
                GlobalPosition = newParent.GlobalPosition + new Vector2(0, 35);

                // 播放堆叠动画
                PlayStackAnimation(newParent);
            }

            EmitSignal(SignalName.StackParentChanged, oldParent, newParent);
        }

        /// <summary>
        /// 解除堆叠
        /// </summary>
        public virtual void Unstack()
        {
            StackOn(null);
        }

        /// <summary>
        /// 获取最底部的卡牌
        /// </summary>
        public BaseCard GetStackRoot()
        {
            BaseCard current = this;
            while (current.StackParent != null)
            {
                current = current.StackParent;
            }
            return current;
        }

        /// <summary>
        /// 获取该堆叠链所属的容器卡（如果是容器的话）
        /// </summary>
        public ContainerCard GetContainer()
        {
            BaseCard root = GetStackRoot();
            return root as ContainerCard;
        }

        /// <summary>
        /// 获取整个堆叠链（从当前卡往上）
        /// </summary>
        public List<BaseCard> GetStackChain()
        {
            List<BaseCard> chain = new List<BaseCard> { this };
            BaseCard child = StackChild;
            while (child != null)
            {
                chain.Add(child);
                child = child.StackChild;
            }
            return chain;
        }

        /// <summary>
        /// 解除堆叠关系并移除卡牌（用于资源卡持续时间耗尽等场景）
        /// </summary>
        protected void UnstackAndRemove()
        {
            BaseCard parent = StackParent;
            BaseCard child = StackChild;

            if (parent != null)
            {
                parent.StackChild = null;
                parent.EmitSignal(SignalName.StackChildChanged, this, default(Variant));
            }
            if (child != null)
            {
                child.StackParent = null;
                child.EmitSignal(SignalName.StackParentChanged, this, default(Variant));
            }
            QueueFree();
        }

        #region 动画接口 (Animation Hooks)

        /// <summary>
        /// 堆叠吸附动画：子类可重写以实现自定义入场效果
        /// </summary>
        protected virtual void PlayStackAnimation(BaseCard target)
        {
            // 默认：微缩放弹跳效果
            Scale = new Vector2(0.8f, 0.8f);
            Tween tween = CreateTween();
            tween.TweenProperty(this, "scale", Vector2.One, 0.15f)
                 .SetTrans(Tween.TransitionType.Elastic)
                 .SetEase(Tween.EaseType.Out);
        }

        /// <summary>
        /// 解除堆叠动画：子类可重写以实现自定义脱离效果
        /// </summary>
        protected virtual void PlayUnstackAnimation()
        {
            Tween tween = CreateTween();
            tween.TweenProperty(this, "scale", new Vector2(1.1f, 1.1f), 0.1f);
            tween.TweenProperty(this, "scale", Vector2.One, 0.1f);
        }

        /// <summary>
        /// 捕食动画（吃虫）：子类可重写，在捕食成功后调用
        /// </summary>
        public virtual void PlayPredationAnimation(Vector2 targetPosition)
        {
            // 默认：短暂冲刺到位再弹回
            Vector2 originalPos = GlobalPosition;
            Tween tween = CreateTween();
            tween.TweenProperty(this, "global_position", targetPosition, 0.08f)
                 .SetTrans(Tween.TransitionType.Quad)
                 .SetEase(Tween.EaseType.In);
            tween.TweenProperty(this, "global_position", originalPos, 0.12f)
                 .SetTrans(Tween.TransitionType.Back)
                 .SetEase(Tween.EaseType.Out);
        }

        /// <summary>
        /// 代谢产物动画（产粪）：子类可重写
        /// </summary>
        public virtual void PlayProduceAnimation()
        {
            // 默认：轻微弹跳
            Tween tween = CreateTween();
            tween.TweenProperty(this, "scale", new Vector2(1.15f, 1.15f), 0.1f);
            tween.TweenProperty(this, "scale", Vector2.One, 0.12f);
        }

        /// <summary>
        /// 受击动画：子类可重写
        /// </summary>
        public virtual void PlayHitAnimation()
        {
            Modulate = new Color(1f, 0.3f, 0.3f, 1f);
            Tween tween = CreateTween();
            tween.TweenProperty(this, "modulate", new Color(1f, 1f, 1f, 1f), 0.2f);
        }

        /// <summary>
        /// 死亡动画：子类可重写，在 Health 归零时调用
        /// </summary>
        public virtual void PlayDeathAnimation()
        {
            Tween tween = CreateTween();
            tween.TweenProperty(this, "modulate", new Color(1f, 1f, 1f, 0f), 0.3f);
            tween.TweenProperty(this, "scale", Vector2.Zero, 0.3f);
        }

        #endregion

        /// <summary>
        /// 生物卡健康值归零时的死亡转化逻辑
        /// </summary>
        public virtual void OnHealthZero()
        {
            EmitSignal(SignalName.HealthZero, this);
            PlayDeathAnimation();
            GD.Print($"[Card] {CardName} Health is zero. Transforming...");

            CardType replacementType = CardType.DryGrass;
            string replacementName = "枯草";

            if (Type == CardType.Fish)
            {
                replacementType = CardType.DeadFish;
                replacementName = "死鱼";
            }

            // 解除所有上下堆叠关系
            BaseCard parent = StackParent;
            BaseCard child = StackChild;

            if (parent != null)
            {
                parent.StackChild = null;
                parent.EmitSignal(SignalName.StackChildChanged, this, default(Variant));
            }
            if (child != null)
            {
                child.StackParent = null;
                child.EmitSignal(SignalName.StackParentChanged, this, default(Variant));
            }

            // 生成替代卡牌
            if (CardSpawner.Instance != null)
            {
                BaseCard newCard = CardSpawner.Instance.SpawnResourceCard(replacementType, replacementName, GlobalPosition);
                // 继承原堆叠结构
                if (newCard != null)
                {
                    if (parent != null) newCard.StackOn(parent);
                    if (child != null) child.StackOn(newCard);
                }
            }

            QueueFree();
        }
    }
}
