using JetBrains.Annotations;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

public class ControllerScript : MonoBehaviour
{
    private Rigidbody2D kirbyBody;
    private BoxCollider2D kirbyBoxCollider;

    public Vector2 moveInput;
    private Vector3 velocity = Vector3.zero;

    private bool facingRight = true;                                            // For determining which way the player is currently facing.

    private float blinkInterval = 100f;
    private float blinkTimer = 0f;

    [SerializeField] private float coyoteTimeCounter;
    [SerializeField] private float coyoteTime = 0.5f;

    private bool hasPressedJump = false;
    private bool hasLetGoJump = true;
    private bool hasDoubleJumped = false;

    //[SerializeField] private bool onGround;                                     // Whether or not the player is grounded
    //[SerializeField] private bool onPlatform;

    [SerializeField] private bool ignorePlatforms;

    [Range(0, .3f)][SerializeField] private float movementSmoothing = .1f;      // How much to smooth out the movement
    [Range(0, 1f)][SerializeField] private float extraHeightTest = 0.12f;

    [Header("Events")]
    [Space]

    public UnityEvent OnFallingEvent;
    public UnityEvent OnGroundedEvent;
    public UnityEvent OnBlinkEvent;
    public UnityEvent OnJumpEvent;

    [System.Serializable]
    public class BoolEvent : UnityEvent<bool> { }

    private void Awake()
    {
        kirbyBody = GetComponent<Rigidbody2D>();
        kirbyBoxCollider = GetComponent<BoxCollider2D>();

        OnFallingEvent ??= new UnityEvent();
        OnGroundedEvent ??= new UnityEvent();
        OnBlinkEvent ??= new UnityEvent();
        OnJumpEvent ??= new UnityEvent();
    }

    private bool IsOnGround()
    {
        RaycastHit2D raycastHit = Physics2D.BoxCast(kirbyBoxCollider.transform.position, kirbyBoxCollider.bounds.size, 0f, Vector2.down, extraHeightTest, LayerMask.GetMask("Ground"));
        
        Color rayColor;
        if (raycastHit.collider != null)
        { rayColor = Color.green; }
        else
        { rayColor = Color.red; }
        
        //Debug.DrawRay(kirbyBoxCollider.transform.position, Vector2.down * (kirbyBoxCollider.bounds.extents.y + extraHeightTest), rayColor);
        return raycastHit.collider != null;
    }

    private bool IsOnPlatform()
    {
        RaycastHit2D raycastHit = Physics2D.BoxCast(kirbyBoxCollider.transform.position, kirbyBoxCollider.bounds.size, 0f, Vector2.down, extraHeightTest, LayerMask.GetMask("Platforms"));

        Color rayColor;
        if (raycastHit.collider != null)
        { rayColor = Color.green; }
        else
        { rayColor = Color.red; }

        //Debug.DrawRay(kirbyBoxCollider.transform.position, Vector2.down * (kirbyBoxCollider.bounds.extents.y + extraHeightTest), rayColor);
        return raycastHit.collider != null;
    }

    private void FixedUpdate()
    {
        if (IsOnGround() || (IsOnPlatform() && !ignorePlatforms))
        {
            coyoteTimeCounter = coyoteTime;

            // Blink
            blinkTimer += Time.deltaTime;
            float blinkValue = Mathf.Floor(blinkInterval * UnityEngine.Random.value);
            if (blinkTimer > blinkValue)
            {
                OnBlinkEvent.Invoke();
                blinkTimer = 0;
            }
            hasPressedJump = false;
            hasDoubleJumped = false;
        }
        else
        {
            if (coyoteTimeCounter > 0)
            {
                coyoteTimeCounter -= Time.deltaTime;
            }
            
        }

        // Check if going down, going up or stationary
        if (kirbyBody.velocity.y < -0.01f)
        {
            OnFallingEvent.Invoke();
        }
        else if (kirbyBody.velocity.y > 0.01f)
        {
            OnJumpEvent.Invoke();
        }
        else if (MathF.Abs(kirbyBody.velocity.y) < 0.01f)
        {
            OnGroundedEvent.Invoke();
        }

        
    }

    public void Move(float move, bool jump, float jumpForce, bool crouch)
    {
        // Move the character by finding the target velocity
        Vector3 targetVelocity = new Vector2(move, kirbyBody.velocity.y);

        // And then smoothing it out and applying it to the character
        kirbyBody.velocity = Vector3.SmoothDamp(kirbyBody.velocity, targetVelocity, ref velocity, movementSmoothing);

        // Flip the player
        if (move > 0 && !facingRight)
            Flip();
        else if (move < 0 && facingRight)
            Flip();

        if (jump)
        {
            if (coyoteTimeCounter > 0f  && !hasPressedJump && hasLetGoJump) 
            {
                hasPressedJump = true;
                Jump(jumpForce);
                //Debug.Log("Normal Jump");
            }

            if (coyoteTimeCounter <= 0f && !hasPressedJump && hasLetGoJump && !hasDoubleJumped)
            {
                hasPressedJump = true;
                Jump(jumpForce);
                hasDoubleJumped = true;
                //Debug.Log("Double Jump");
            }

            hasLetGoJump = false;
        }

        if (!jump)
        {
            hasPressedJump = false;
            coyoteTimeCounter = 0f;
            hasLetGoJump = true;
        }

        if (kirbyBody.velocity.y > 0.1f || crouch)
        {
            IgnorePlatforms(true);
        }
        if (kirbyBody.velocity.y <= 0.1f && (!crouch && !IsOnPlatform()))
        {
            IgnorePlatforms(false);
        }
    }

    private void IgnorePlatforms(bool activate)
    {
        Physics2D.IgnoreLayerCollision(3, 7, activate);
        ignorePlatforms = activate;
        if (activate)
        {
            //Debug.Log("ignorePlatforms = " + activate);
        }
    }

    private void Flip()
    {
        // Rotate 180 on Y-axis
        if (facingRight)
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 180f, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }
        else
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 0, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }

        // Switch the way the player is labelled as facing.
        facingRight = !facingRight;
    }

    private void Jump(float addJumpForce)
    {
        // Stop vertical movement
        Vector2 oldVector = kirbyBody.velocity;
        Vector2 oldPos = kirbyBody.position;

        //kirbyBody.position = new Vector2(oldPos.x, oldPos.y + 0.5f);
        kirbyBody.velocity = new Vector2(oldVector.x, 0f);

        // Add a vertical force to the player.
        kirbyBody.AddForce(new Vector2(0f, addJumpForce));
    }
}
