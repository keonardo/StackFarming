using Godot;
using System;

namespace StackFarming
{
    public partial class CardSpawner : Node
    {
        public static CardSpawner Instance { get; private set; }

        private PackedScene _resourceCardScene;
        private PackedScene _creatureCardScene;
        private PackedScene _containerCardScene;
        private PackedScene _pestCardScene;

        public override void _EnterTree()
        {
            Instance = this;
            
            // 预加载场景文件
            _resourceCardScene = GD.Load<PackedScene>("res://Scenes/resource_card.tscn");
            _creatureCardScene = GD.Load<PackedScene>("res://Scenes/creature_card.tscn");
            _containerCardScene = GD.Load<PackedScene>("res://Scenes/container_card.tscn");
            _pestCardScene = GD.Load<PackedScene>("res://Scenes/pest_card.tscn");
        }

        public override void _ExitTree()
        {
            if (Instance == this)
            {
                Instance = null;
            }
        }

        /// <summary>
        /// 实例化一个资源卡牌 (Feces, DeadFish, DryGrass 等)
        /// </summary>
        public BaseCard SpawnResourceCard(CardType type, string cardName, Vector2 position)
        {
            BaseCard card;
            if (_resourceCardScene != null)
            {
                card = _resourceCardScene.Instantiate<BaseCard>();
            }
            else
            {
                card = new BaseCard();
                AddCollisionToCard(card);
            }

            card.Role = CardRole.Resource;
            card.Type = type;
            card.CardName = cardName;
            card.ValueA = 10f; // 默认强度 (Intensity)
            card.ValueB = 60f; // 默认持续时间 (Duration)
            card.GlobalPosition = position;

            GetTree().Root.CallDeferred(MethodName.AddChild, card);
            return card;
        }

        /// <summary>
        /// 实例化一个生物卡牌 (Animal, Crop, Fish)
        /// </summary>
        public CreatureCard SpawnCreatureCard(CardType type, string cardName, Vector2 position)
        {
            CreatureCard card;
            if (_creatureCardScene != null)
            {
                card = _creatureCardScene.Instantiate<CreatureCard>();
            }
            else
            {
                card = new CreatureCard();
                AddCollisionToCard(card);
            }

            card.Role = CardRole.Creature;
            card.Type = type;
            card.CardName = cardName;
            card.ValueA = 100f; // 默认健康值 (Health)
            card.ValueB = 0f;   // 默认生产/生长进度 (Progress)
            card.GlobalPosition = position;

            GetTree().Root.CallDeferred(MethodName.AddChild, card);
            return card;
        }

        /// <summary>
        /// 实例化害虫卡
        /// </summary>
        public PestCard SpawnPestCard(Vector2 position)
        {
            PestCard card;
            if (_pestCardScene != null)
            {
                card = _pestCardScene.Instantiate<PestCard>();
            }
            else
            {
                card = new PestCard();
                AddCollisionToCard(card);
            }

            card.Role = CardRole.Creature;
            card.Type = CardType.Pest;
            card.CardName = "害虫";
            card.ValueA = 50f; // 默认健康值 (Health)
            card.ValueB = 0f;
            card.GlobalPosition = position;

            GetTree().Root.CallDeferred(MethodName.AddChild, card);
            return card;
        }

        /// <summary>
        /// 实例化容器卡牌 (Farmland, DeepWaterFishPond, River, Canal)
        /// </summary>
        public ContainerCard SpawnContainerCard(CardType type, string cardName, Vector2 position)
        {
            ContainerCard card;
            if (_containerCardScene != null)
            {
                card = _containerCardScene.Instantiate<ContainerCard>();
            }
            else
            {
                card = new ContainerCard();
                AddCollisionToCard(card);
            }

            card.Role = CardRole.Container;
            card.Type = type;
            card.CardName = cardName;
            card.ValueA = 5f;   // 默认承载力 (Capacity)
            card.ValueB = 100f; // 默认滋润度 (Moisture)
            card.GlobalPosition = position;

            GetTree().Root.CallDeferred(MethodName.AddChild, card);
            return card;
        }

        private void AddCollisionToCard(Area2D card)
        {
            var collisionShape = new CollisionShape2D();
            var rectangleShape = new RectangleShape2D();
            rectangleShape.Size = new Vector2(80, 100); // 统一卡牌碰撞尺寸
            collisionShape.Shape = rectangleShape;
            card.AddChild(collisionShape);
        }
    }
}
